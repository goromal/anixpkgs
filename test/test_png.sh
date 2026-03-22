anixdir="$(dirname $PWD)"
export NIX_PATH="anixpkgs=$anixdir:$NIX_PATH"
tmpdir="$anixdir/test/tmpdir"
if [[ -d $tmpdir ]]; then
    rm -rf $tmpdir
fi
mkdir $tmpdir
cd $tmpdir

make-title -c yellow "Testing PNG tools"

png 4444-400-200.random my.png
ckfile -c 5ccd6f61bddaae29a2c2b56a1561a1dd my.png || { echo_red "Unexpected random PNG hash"; exit 1; }
ckfile -c 5ccd6f61bddaae29da2c2b56a1561a1dd my.png && { echo_red "Unexpected random PNG hash check"; exit 1; }

# Cleanup
rm -rf "$tmpdir"
