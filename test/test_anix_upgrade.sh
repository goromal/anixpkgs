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
