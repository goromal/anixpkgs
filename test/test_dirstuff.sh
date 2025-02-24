anixdir="$(dirname $PWD)"
export NIX_PATH="anixpkgs=$anixdir:$NIX_PATH"
tmpdir="$anixdir/test/tmpdir"
if [[ -d $tmpdir ]]; then
    rm -rf $tmpdir
fi
mkdir $tmpdir
cd $tmpdir

make-title -c yellow "Testing directory manipulation tools"
cd $tmpdir
mkdir dirtests && cd dirtests
for i in 1 2 3 4; do
    dname=dir$i
    mkdir $dname
    for j in 1 2 3 4; do
        touch "$dname/$j.txt"
    done
done
dirgather . gathered
numdirs=$(ls | wc -l)
[[ "$numdirs" == "1" ]] || { echo_red "dirgather failed to clean up empty directories"; exit 1; }
numgathered=$(ls gathered | wc -l)
[[ "$numgathered" == "16" ]] || { echo_red "Unexpected number of gathered files: $numgathered != 16"; exit 1; }
cp -r gathered gathered2
dirgroups 3 gathered
dirgroups --of 6 gathered2
[[ "$(ls gathered/_split_1 | wc -l)" == "6" ]] || { echo_red "Bad dirgroup results:"; ls -R gathered; exit 1; }
[[ "$(ls gathered/_split_2 | wc -l)" == "6" ]] || { echo_red "Bad dirgroup results:"; ls -R gathered; exit 1; }
[[ "$(ls gathered/_split_3 | wc -l)" == "4" ]] || { echo_red "Bad dirgroup results:"; ls -R gathered; exit 1; }
[[ "$(ls gathered2/_split_1 | wc -l)" == "6" ]] || { echo_red "Bad dirgroup results:"; ls -R gathered2; exit 1; }
[[ "$(ls gathered2/_split_2 | wc -l)" == "6" ]] || { echo_red "Bad dirgroup results:"; ls -R gathered2; exit 1; }
[[ "$(ls gathered2/_split_3 | wc -l)" == "4" ]] || { echo_red "Bad dirgroup results:"; ls -R gathered2; exit 1; }

# Cleanup
rm -rf "$tmpdir"
