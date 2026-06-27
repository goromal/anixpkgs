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

make-title -c yellow "Testing sunnyside bu/rs (file)"
echo "BACKUP_TEST" > original.txt
sunnyside bu -t original.txt -s 4 -k u -d backup.tyz
[[ -f backup.tyz ]] || { echo_red "bu: dest not created"; exit 1; }
sunnyside rs -t backup.tyz -s 4 -k u -d restored.txt
[[ "$(cat restored.txt)" == "BACKUP_TEST" ]] || { echo_red "rs: file content mismatch"; exit 1; }

make-title -c yellow "Testing sunnyside bu/rs (directory)"
mkdir -p testdir/sub
echo "NESTED" > testdir/sub/file.txt
sunnyside bu -t testdir -s 4 -k u -d dir_backup.tyz
[[ -f dir_backup.tyz ]] || { echo_red "bu: dir dest not created"; exit 1; }
sunnyside rs -t dir_backup.tyz -s 4 -k u -d testdir_restored
[[ "$(cat testdir_restored/sub/file.txt)" == "NESTED" ]] || { echo_red "rs: dir content mismatch"; exit 1; }

# Cleanup
rm -rf "$tmpdir"
