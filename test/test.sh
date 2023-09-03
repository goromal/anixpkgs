set -e pipefail

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
echo "[mscpp] = pkgs mscpp" >> data/devrc
echo "test = manif-geom-cpp mscpp" >> data/devrc
devshell -d data/devrc test --run "touch sources/test1 && mkdir sources/test2 && export WSROOT="$tmpdir/dev/test" && listsources"
echo "[geometry] = https://github.com/goromal/geometry" >> data/devrc
echo "test_env = geometry manif-geom-cpp" >> data/devrc
devshell -d data/devrc test_env --run "export WSROOT="$tmpdir/dev/test_env" && listsources"

make-title -c yellow "Clean up"
cd "$anixdir/test"
rm -rf $tmpdir

make-title -c green PASSED
