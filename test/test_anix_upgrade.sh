#!/usr/bin/env bash

set -euo pipefail

upgrade=$(command -v anix-upgrade)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

mock_bin="$test_root/bin"
mkdir -p "$mock_bin"

cat > "$mock_bin/atsudo" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$ANIX_UPGRADE_TEST_LOG"
if [[ "${ANIX_UPGRADE_FAIL_REBUILD:-0}" == "1" && "$*" == *"nixos-rebuild"* ]]; then
  exit 1
fi
EOF
cat > "$mock_bin/nixos-version" <<'EOF'
#!/usr/bin/env bash
echo 26.05
EOF
cat > "$mock_bin/hostname" <<'EOF'
#!/usr/bin/env bash
echo test-host
EOF
cat > "$mock_bin/nix" <<'EOF'
#!/usr/bin/env bash
printf 'NIX_PATH=%s nix %s\n' "${NIX_PATH:-}" "$*" >> "$ANIX_UPGRADE_TEST_LOG"
if [[ "$*" == "eval --impure --raw --expr builtins.currentSystem" ]]; then
  printf 'x86_64-linux'
elif [[ "$*" == eval\ --raw\ *legacyPackages.x86_64-linux.path ]]; then
  printf '/nix/store/mock-nixpkgs'
elif [[ "$*" == run\ *#home-manager\ --\ switch\ -f\ * ]]; then
  [[ "${ANIX_UPGRADE_FAIL_HOME:-0}" != "1" ]]
else
  echo "Unexpected nix invocation: $*" >&2
  exit 1
fi
EOF
cat > "$mock_bin/home-manager" <<'EOF'
#!/usr/bin/env bash
printf 'NIX_PATH=%s home-manager %s\n' "${NIX_PATH:-}" "$*" >> "$ANIX_UPGRADE_TEST_LOG"
[[ "${ANIX_UPGRADE_FAIL_HOME:-0}" != "1" ]]
EOF
chmod +x "$mock_bin"/*

make_source() {
  local path=$1
  local version=$2
  local mode=${3:-}

  mkdir -p "$path/pkgs/nixos"
  mkdir -p "$path/pkgs/nixos/configurations"
  printf 'v0.0.0\n' > "$path/ANIX_VERSION"
  printf '%s\n' "$version" > "$path/NIXOS_VERSION"
  printf 'local-build = false;\n' > "$path/pkgs/nixos/dependencies.nix"
  printf '{}\n' > "$path/pkgs/nixos/configurations/test-host.nix"
  if [[ -n "$mode" ]]; then
    printf '%s\n' "$mode" > "$path/NIXOS_REBUILD_MODE"
  fi
  git -C "$path" init -q
  git -C "$path" add .
}

run_upgrade() {
  local case_name=$1
  local source=$2
  local case_home="$test_root/$case_name"

  mkdir -p "$case_home/sources"
  printf 'v0.0.0\n' > "$case_home/.anix-version"
  ANIX_UPGRADE_TEST_LOG="$case_home/commands.log" \
    HOME="$case_home" \
    PATH="$mock_bin:$PATH" \
    "$upgrade" --source "$source"
}

flake_source="$test_root/flake-source"
make_source "$flake_source" 26.05 flake
run_upgrade flake "$flake_source"
grep -Fq "NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild switch --flake $test_root/flake/sources/anixpkgs#test-host --impure" \
  "$test_root/flake/commands.log"
if grep -Fq 'nix-channel' "$test_root/flake/commands.log"; then
  echo "flake rebuild unexpectedly changed channels" >&2
  exit 1
fi

legacy_source="$test_root/legacy-source"
make_source "$legacy_source" 25.11
run_upgrade legacy "$legacy_source"
grep -Fq 'nix-channel --add https://nixos.org/channels/nixos-25.11 nixpkgs' "$test_root/legacy/commands.log"
grep -Fxq "NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild switch -I nixos-config=$test_root/legacy/sources/anixpkgs/pkgs/nixos/configurations/test-host.nix" \
  "$test_root/legacy/commands.log"

restore_home="$test_root/restore"
mkdir -p "$restore_home/sources/anixpkgs"
printf 'keep me\n' > "$restore_home/sources/anixpkgs/sentinel"
printf 'v0.0.0\n' > "$restore_home/.anix-version"
if ANIX_UPGRADE_TEST_LOG="$restore_home/commands.log" \
  ANIX_UPGRADE_FAIL_REBUILD=1 \
  HOME="$restore_home" \
  PATH="$mock_bin:$PATH" \
  "$upgrade" --source "$flake_source"; then
  echo "failed rebuild unexpectedly succeeded" >&2
  exit 1
fi
grep -Fxq 'keep me' "$restore_home/sources/anixpkgs/sentinel"

relative_home="$test_root/relative"
mkdir -p "$relative_home/sources/anixpkgs"
printf 'keep me\n' > "$relative_home/sources/anixpkgs/sentinel"
printf 'v0.0.0\n' > "$relative_home/.anix-version"
if ANIX_UPGRADE_TEST_LOG="$relative_home/commands.log" \
  HOME="$relative_home" PATH="$mock_bin:$PATH" \
  "$upgrade" --source relative/path; then
  echo "relative source unexpectedly succeeded" >&2
  exit 1
fi
grep -Fxq 'keep me' "$relative_home/sources/anixpkgs/sentinel"

same_source_home="$test_root/same-source"
mkdir -p "$same_source_home/sources/anixpkgs"
printf 'keep me\n' > "$same_source_home/sources/anixpkgs/sentinel"
printf 'v0.0.0\n' > "$same_source_home/.anix-version"
if ANIX_UPGRADE_TEST_LOG="$same_source_home/commands.log" \
  HOME="$same_source_home" PATH="$mock_bin:$PATH" \
  "$upgrade" --source "$same_source_home/sources/anixpkgs"; then
  echo "managed source tree unexpectedly accepted itself as input" >&2
  exit 1
fi
grep -Fxq 'keep me' "$same_source_home/sources/anixpkgs/sentinel"

missing_sources_home="$test_root/missing-sources"
missing_sources_cwd="$test_root/unrelated-cwd"
mkdir -p "$missing_sources_home" "$missing_sources_cwd/anixpkgs"
printf 'keep me\n' > "$missing_sources_cwd/anixpkgs/sentinel"
if (
  cd "$missing_sources_cwd"
  ANIX_UPGRADE_TEST_LOG="$missing_sources_home/commands.log" \
    HOME="$missing_sources_home" PATH="$mock_bin:$PATH" \
    "$upgrade" --source "$flake_source"
); then
  echo "missing sources directory unexpectedly succeeded" >&2
  exit 1
fi
grep -Fxq 'keep me' "$missing_sources_cwd/anixpkgs/sentinel"

if [[ -z "${ANIX_UPGRADE_STANDALONE_BIN:-}" ]]; then
  echo "ANIX_UPGRADE_STANDALONE_BIN is required" >&2
  exit 1
fi

standalone_home="$test_root/standalone"
mkdir -p "$standalone_home/sources/anixpkgs" "$standalone_home/.config/home-manager"
printf 'old source\n' > "$standalone_home/sources/anixpkgs/sentinel"
printf 'v0.0.0\n' > "$standalone_home/.anix-version"
printf '{}\n' > "$standalone_home/.config/home-manager/home.nix"
ANIX_UPGRADE_TEST_LOG="$standalone_home/commands.log" \
  HOME="$standalone_home" PATH="$mock_bin:$PATH" \
  "$ANIX_UPGRADE_STANDALONE_BIN" --source "$flake_source"
grep -Fq "NIX_PATH=nixpkgs=/nix/store/mock-nixpkgs" "$standalone_home/commands.log"
grep -Fq \
  "nix run $standalone_home/sources/anixpkgs#home-manager -- switch -f $standalone_home/.config/home-manager/home.nix" \
  "$standalone_home/commands.log"

standalone_restore_home="$test_root/standalone-restore"
mkdir -p "$standalone_restore_home/sources/anixpkgs" "$standalone_restore_home/.config/home-manager"
printf 'keep me\n' > "$standalone_restore_home/sources/anixpkgs/sentinel"
printf 'v0.0.0\n' > "$standalone_restore_home/.anix-version"
printf '{}\n' > "$standalone_restore_home/.config/home-manager/home.nix"
if ANIX_UPGRADE_TEST_LOG="$standalone_restore_home/commands.log" \
  ANIX_UPGRADE_FAIL_HOME=1 \
  HOME="$standalone_restore_home" PATH="$mock_bin:$PATH" \
  "$ANIX_UPGRADE_STANDALONE_BIN" --source "$flake_source"; then
  echo "failed standalone switch unexpectedly succeeded" >&2
  exit 1
fi
grep -Fxq 'keep me' "$standalone_restore_home/sources/anixpkgs/sentinel"

standalone_legacy_home="$test_root/standalone-legacy"
mkdir -p "$standalone_legacy_home/sources" "$standalone_legacy_home/.config/home-manager"
printf 'v0.0.0\n' > "$standalone_legacy_home/.anix-version"
printf '{}\n' > "$standalone_legacy_home/.config/home-manager/home.nix"
ANIX_UPGRADE_TEST_LOG="$standalone_legacy_home/commands.log" \
  HOME="$standalone_legacy_home" PATH="$mock_bin:$PATH" \
  "$ANIX_UPGRADE_STANDALONE_BIN" --source "$legacy_source"
grep -Fq \
  "home-manager switch -f $standalone_legacy_home/.config/home-manager/home.nix" \
  "$standalone_legacy_home/commands.log"
if grep -Fq '#home-manager' "$standalone_legacy_home/commands.log"; then
  echo "legacy standalone upgrade unexpectedly used the target flake" >&2
  exit 1
fi
