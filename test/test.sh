set -eo pipefail

make-title -c yellow "Setting up"
anixdir="$(dirname $PWD)"
export NIX_PATH="anixpkgs=$anixdir:$NIX_PATH"
tmpdir="$anixdir/test/tmpdir"
if [[ -d $tmpdir ]]; then
    rm -rf $tmpdir
fi
mkdir $tmpdir
cd $tmpdir

make-title -c yellow "Testing workspace tools"
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
echo "[geometry] = pkgs python39.pkgs.geometry" >> data/devrc
echo "[pyceres_factors] = pkgs python39.pkgs.pyceres_factors" >> data/devrc
echo "[ceres-factors] = pkgs ceres-factors" >> data/devrc
echo "test_env = geometry manif-geom-cpp ceres-factors pyceres_factors" >> data/devrc
devshell -d data/devrc test_env --run "export WSROOT="$tmpdir/dev/test_env""
if [[ -z $(cat $tmpdir/dev/test_env/shell.nix | grep "inherit ceres-factors;") ]]; then
    echo_red "setupcurrentws missed shell pkg intra-workspace dependency"
    exit 1
fi
sed -i 's|python3\.|python39\.|g' $tmpdir/dev/test_env/shell.nix
devshell -d data/devrc test_env --run "export WSROOT="$tmpdir/dev/test_env""
if [[ -z $(cat $tmpdir/dev/test_env/shell.nix | grep "pkgs.python39.withPackages") ]]; then
    echo_red "setupcurrentws overrode an edited shell file"
    exit 1
fi

make-title -c yellow "Clean up"
cd "$anixdir/test"
rm -rf $tmpdir

make-title -c green PASSED
