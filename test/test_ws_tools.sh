anixdir="$(dirname $PWD)"
export NIX_PATH="anixpkgs=$anixdir:$NIX_PATH"
tmpdir="$anixdir/test/tmpdir"
if [[ -d $tmpdir ]]; then
    rm -rf $tmpdir
fi
mkdir $tmpdir
cd $tmpdir

make-title -c yellow "Testing workspace tools"
cd $tmpdir
mkdir dev
mkdir data
echo "pkgs_var = <anixpkgs>" > data/devrc
echo "dev_dir = $tmpdir/dev" >> data/devrc
echo "data_dir = $tmpdir/data" >> data/devrc
echo "pkgs_dir = $anixdir" >> data/devrc
echo "[manif-geom-cpp] = pkgs manif-geom-cpp" >> data/devrc
echo "[mscpp] = https://github.com/goromal/mscpp" >> data/devrc
echo "test = manif-geom-cpp mscpp" >> data/devrc
devshell -d data/devrc test --run "touch sources/test1 && mkdir sources/test2 && export WSROOT="$tmpdir/dev/test" && listsources"
if [[ ! -d $tmpdir/dev/test/sources/mscpp ]]; then
    echo_red "Failed to clone mscpp github repo"
    exit 1
fi
if [[ -z $(cat $tmpdir/dev/test/shell.nix | grep "pkg-src = pkgs.lib.cleanSource ./sources/manif-geom-cpp/.;") ]]; then
    echo_red "devshell didn\'t make the correct source override in shell file"
    exit 1
fi
echo "[geometry] = pkgs python311.pkgs.geometry" >> data/devrc
echo "[pyceres_factors] = pkgs python311.pkgs.pyceres_factors" >> data/devrc
echo "[ceres-factors] = pkgs ceres-factors" >> data/devrc
echo "test_env = geometry manif-geom-cpp ceres-factors pyceres_factors" >> data/devrc
devshell --override-data-dir "$tmpdir/data2" -d data/devrc test_env --run "export WSROOT="$tmpdir/dev/test_env""
if [[ -z $(cat $tmpdir/dev/test_env/shell.nix | grep "inherit ceres-factors;") ]]; then
    echo_red "setupcurrentws missed shell pkg intra-workspace dependency"
    exit 1
fi
if [[ ! -f $tmpdir/dev/test_env/.claude/CLAUDE.md ]]; then
    echo_red "Failed to create root claude boilerplate"
    exit 1
fi
if [[ ! -f $tmpdir/dev/test_env/sources/.claude/CLAUDE.md ]]; then
    echo_red "Failed to create source claude boilerplate"
    exit 1
fi
if [[ ! -f $tmpdir/dev/test_env/.claude/AGENTS.md ]]; then
    echo_red "Failed to create AGENTS.md with beans instructions"
    exit 1
fi
if command -v beans &> /dev/null; then
  # Check data directory has actual beans files
  if [[ ! -f $tmpdir/data2/.beans.yml ]]; then
      echo_red "Failed to create beans config in data directory"
      exit 1
  fi
  if [[ ! -d $tmpdir/data2/.beans ]]; then
      echo_red "Failed to create beans directory in data directory"
      exit 1
  fi
  # Check workspace root has symlinks
  if [[ ! -L $tmpdir/dev/test_env/.beans.yml ]] || [[ $(readlink $tmpdir/dev/test_env/.beans.yml) != "$tmpdir/data2/.beans.yml" ]]; then
      echo_red "Failed to symlink beans config in workspace root"
      exit 1
  fi
  if [[ ! -L $tmpdir/dev/test_env/.beans ]] || [[ $(readlink $tmpdir/dev/test_env/.beans) != "$tmpdir/data2/.beans" ]]; then
      echo_red "Failed to symlink beans directory in workspace root"
      exit 1
  fi
  # Check sources directory has symlinks
  if [[ ! -L $tmpdir/dev/test_env/sources/.beans.yml ]] || [[ $(readlink $tmpdir/dev/test_env/sources/.beans.yml) != "$tmpdir/data2/.beans.yml" ]]; then
      echo_red "Failed to symlink beans config in sources directory"
      exit 1
  fi
  if [[ ! -L $tmpdir/dev/test_env/sources/.beans ]] || [[ $(readlink $tmpdir/dev/test_env/sources/.beans) != "$tmpdir/data2/.beans" ]]; then
      echo_red "Failed to symlink beans directory in sources directory"
      exit 1
  fi
fi
[[ -d "$tmpdir/data2" ]] || { echo_red "Failed data dir override"; exit 1; }
echo "<scr> = scripts/test" >> data/devrc
echo "scr_env = geometry" >> data/devrc
mkdir -p "$tmpdir/data/scripts"
echo "#!/usr/bin/env bash" > "$tmpdir/data/scripts/test"
echo "touch FILE.txt" >> "$tmpdir/data/scripts/test"
chmod +x "$tmpdir/data/scripts/test"
devshell -d $tmpdir/data/devrc scr_env --run "addscr scr"
[[ -f "$tmpdir/dev/scr_env/.bin/scr" ]] || { echo "Failed devshell script gather"; exit 1; }
sed -i 's|python3\.|python311\.|g' $tmpdir/dev/test_env/shell.nix
devshell -d data/devrc test_env --run "export WSROOT="$tmpdir/dev/test_env""
if [[ -z $(cat $tmpdir/dev/test_env/shell.nix | grep "pkgs.python311.withPackages") ]]; then
    echo_red "setupcurrentws overrode an edited shell file"
    exit 1
fi
devshell -d $tmpdir/data/devrc test_env --run "addsrc task-tools https://github.com/goromal/task-tools"
[[ -d $tmpdir/dev/test_env/sources/task-tools ]] || { echo_red "Failed to add source to workspace"; exit 1; }
cd $tmpdir/dev/test_env/sources/ceres-factors
cpp-helper nix
sed -i 's|# ADD deps|eigen ceres-solver manif-geom-cpp boost|g' shell.nix
cpp-helper vscode
echo 'Checking generated VSCode config'
if [[ -z $(cat .vscode/c_cpp_properties.json | grep manif-geom-cpp) ]]; then
    echo_red "VSCode C++ config improperly generated"
    exit 1
fi
cd $tmpdir/dev
setupws --dev_dir $tmpdir/dev --data_dir $tmpdir/data tws2 lint.sh=$anixdir/scripts/lint.sh mscpf:https://github.com/goromal/mscpp
[[ -d "$tmpdir/dev/tws2/sources/mscpf/.git" ]] || { echo "setupws repo clone failed"; exit 1; }
[[ -f "$tmpdir/dev/tws2/.bin/lint.sh" ]] || { echo "setupws script copy failed"; exit 1; }
pkgshell anixpkgs sunnyside --run "sunnyside --help"

# Cleanup
rm -rf "$tmpdir"
