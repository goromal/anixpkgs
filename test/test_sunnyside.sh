anixdir="$(dirname $PWD)"
export NIX_PATH="anixpkgs=$anixdir:$NIX_PATH"
tmpdir="$anixdir/test/tmpdir"
if [[ -d $tmpdir ]]; then
    rm -rf $tmpdir
fi
mkdir $tmpdir
cd $tmpdir

make-title -c yellow "Testing sunnyside and sread"
echo "SUCCESS" > test.py
sunnyside -t test.py -s 4 -k u
rm test.py
[[ -f xiwx3tC.tyz ]] || { echo_red "sunnyside rename failed"; exit 1; }
sunnyside -t xiwx3tC.tyz -s 4 -k u
[[ -f test.py ]] || { echo_red "sunnyside re-rename failed"; exit 1; }
if [[ -z $(cat test.py | grep SUCCESS) ]]; then
    echo_red "sunnyside reconstruction failed"
    exit 1
fi

echo "u" > cipher
swrite -c cipher test.py
ccontent=$(sread -c cipher test.py.tyz)
if [[ "$ccontent" != "SUCCESS" ]]; then
    echo_red "sread failed: $ccontent != SUCCESS"
    exit 1
fi

# Cleanup
rm -rf "$tmpdir"
