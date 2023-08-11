set -e pipefail

make-title -c yellow "Setting up"
anixdir="$(dirname $PWD)"
export NIX_PATH="anixpkgs=$anixdir:$NIX_PATH"
tmpdir="$anixdir/test/tmpdir"
if [[ -d $tmpdir ]]; then
    rm -rf $tmpdir
fi
mkdir $tmpdir
cp -r data $tmpdir

cd $tmpdir
mkdir dev

make-title -c yellow "Testing workspace tools"
echo "dev_dir = $tmpdir/dev" >> data/devrc
echo "data_dir = $tmpdir/data" >> data/devrc
echo "pkgs_dir = $anixdir" >> data/devrc
devshell -d data/devrc test --run "setupcurrentws"
pushd dev/test
touch sources/test1 && mkdir sources/test2
export WSROOT="$tmpdir/dev/test"
listsources
popd

make-title -c yellow "Clean up"
cd "$anixdir/test"
rm -rf $tmpdir

make-title -c green PASSED
