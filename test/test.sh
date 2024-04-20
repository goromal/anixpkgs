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
cd $tmpdir/dev/test_env/sources/ceres-factors
cpp-helper --make-nix
sed -i 's|# ADD deps|eigen ceres-solver manif-geom-cpp boost|g' shell.nix
nix-shell --run "echo 'Checking generated VSCode config'"
if [[ -z $(cat .vscode/c_cpp_properties.json | grep manif-geom-cpp) ]]; then
    echo_red "VSCode C++ config improperly generated"
    exit 1
fi
cd ../../..
touch test.py
pkgshell anixpkgs sunnyside --run "sunnyside test.py 4 u"
[[ -f xiwx3tC.tyz ]] || { echo_red "pkgshell:sunnyside command failed"; exit 1; }

make-title -c yellow "Testing orchestrator"
cd $tmpdir
mkdir orch_data
orchoutpath="$tmpdir/orch_data"
oinf1="$orchoutpath/sample_960x400_ocean_with_audio.webm"
oinf2="$orchoutpath/sample_1280x720.webm"
oinf3="$orchoutpath/sample_1920x1080.webm"
oinf4="$orchoutpath/sample_2560x1440.webm"
oinf5="$orchoutpath/sample_3840x2160.webm"
oinf6="$orchoutpath/sample_640x360.webm"
oinf7="$orchoutpath/sample_960x540.webm"

num_server_threads=2

echo "Using scrape to obtain input files..."

scrape --xpath body/div --ext webm --output $orchoutpath simple-link-scraper https://goromal.github.io/anixpkgs/python/scrape.html
for f in "$oinf1" "$oinf2" "$oinf3" "$oinf4" "$oinf5" "$oinf6" "$oinf7"; do
    [[ -f "$f" ]] || { echo_red "Expected scraped file $f not present"; exit 1;  }
done

echo "Spawning server with $num_server_threads threads"

nohup orchestratord -p 5555 -n $num_server_threads > /dev/null 2>&1 &
serverPID=$!

sleep 4

echo "Spawning jobs"

rmjob=$(orchestrator -p 5555 remove $orchoutpath/sample_960x400_ocean_with_audio.webm)
rmjob=$(orchestrator -p 5555 remove -b $rmjob $orchoutpath/sample_1280x720.webm)
rmjob=$(orchestrator -p 5555 remove -b $rmjob $orchoutpath/sample_1920x1080.webm)
rmjob=$(orchestrator -p 5555 remove -b $rmjob $orchoutpath/sample_2560x1440.webm)
rmjob=$(orchestrator -p 5555 remove -b $rmjob $orchoutpath/sample_3840x2160.webm)
lsjob=$(orchestrator -p 5555 listing -b $rmjob --ext webm $orchoutpath)
mp4job=$(orchestrator -p 5555 mp4 $lsjob $orchoutpath/vid.mp4)
rmjob=$(orchestrator -p 5555 remove $lsjob -b $mp4job)
unijob=$(orchestrator -p 5555 mp4-unite $mp4job $orchoutpath/unified_vid.mp4)
rmjob=$(orchestrator -p 5555 remove $mp4job -b $unijob)

echo "touch $orchoutpath/new.txt" > "$tmpdir/touchfile.sh"
bjob=$(orchestrator -p 5555 bash "bash $tmpdir/touchfile.sh")

num_pending=1
timeout_secs=60
num_tries=0

echo "Waiting for pending jobs..."

while (( num_pending > 0 )) && (( num_tries < timeout_secs )); do
    num_pending=$(orchestrator -p 5555 status count-pending)
    echo "Filesystem: ($num_pending)"
    ls $orchoutpath
    echo "----------------"
    num_tries=$(( num_tries+1 ))
    sleep 1
done

if [ $num_pending -ne 0 ]; then
    echo_red "ERROR: orchestrator timed out at $timeout_secs seconds with $num_pending unfinished jobs:"
    for jid in $(orchestrator -p 5555 status get-pending); do
        orchestrator -p 5555 status $jid
    done
    kill $serverPID
    exit 1
fi

echo "All jobs complete at $num_tries seconds"
for jid in $(orchestrator -p 5555 status get-complete); do
    orchestrator -p 5555 status $jid
done

num_discarded=$(orchestrator -p 5555 status count-discarded)
if [ $num_discarded -ne 0 ]; then
    echo_red "ERROR: orchestrator finished with $num_discarded discarded jobs:"
    for jid in $(orchestrator -p 5555 status get-discarded); do
        orchestrator -p 5555 status $jid
    done
    kill $serverPID
    exit 1
fi

if [ ! -f "$orchoutpath/unified_vid.mp4" ]; then
    echo_red "ERROR: expected workflow output video not present"
    kill $serverPID
    exit 1
fi

if [ ! -f "$orchoutpath/new.txt" ]; then
    echo_red "ERROR: expected workflow output file not present"
    kill $serverPID
    exit 1
fi

num_outputs=$(ls -1 "$orchoutpath" | wc -l)
if [ $num_outputs -ne 2 ]; then
    echo_red "ERROR: extra outputs present"
    kill $serverPID
    exit 1
fi

echo "Passed, killing server"
kill $serverPID

make-title -c yellow "Testing fix-perms"
cd $tmpdir
for dir_desc in fp_test/.ssh/domain fp_test/reg/reg2; do
    mkdir -p $dir_desc
    chmod 777 $dir_desc
done
for file_desc in fp_test/.ssh/private_key fp_test/.ssh/config fp_test/.ssh/private_key.pub \
  fp_test/.ssh/domain/private_key fp_test/reg/file1 fp_test/reg/reg2/file2; do
    touch $file_desc
    chmod 664 $file_desc
done
fix-perms fp_test/reg && cd fp_test/.ssh && fix-perms . && cd ..
[[ "$(stat -c '%a' .ssh/private_key)" ==  "600" ]] || { echo_red "Private SSH key granted incorrect permissions"; exit 1; }
[[ "$(stat -c '%a' .ssh/private_key.pub)" == "644" ]] || { echo_red "Public SSH key granted incorrect permissions"; exit 1; }
[[ "$(stat -c '%a' .ssh/domain)" == "700" ]] || { echo_red "SSH directory granted incorrect permissions"; exit 1; }
[[ "$(stat -c '%a' .ssh/domain/private_key)" == "600" ]] || { echo_red "SSH nested private key granted incorrect permissions"; exit 1; }
[[ "$(stat -c '%a' reg/reg2/file2)" == "644" ]] || { echo_red "Nested file granted incorrect permissions"; exit 1; }
[[ "$(stat -c '%a' reg/reg2)" == "755" ]] || { echo_red "Directory granted incorrect permissions"; exit 1; }

make-title -c yellow "Testing source fetcher"
cd $tmpdir
mkdir pkg_srcs
cd pkg_srcs
nix-build -E 'with (import (../../../default.nix) {}); pkgsSource { local = false; ref = "refs/tags/v2.2.0"; }' -o src1
if [[ -z $(cat src1/ANIX_VERSION | grep 2\.2\.0) ]]; then
    echo_red "Failed to fetch anixpkgs 2.2.0 by tag; received $(cat src1/ANIX_VERSION)"
    exit 1
fi
nix-build -E 'with (import (../../../default.nix) {}); pkgsSource { local = false; rev = "d393a9ba7d5b9b40fb2f774a2c216002a89810c5"; }' -o src2
if [[ -z $(cat src2/ANIX_VERSION | grep 2\.1\.1) ]]; then
    echo_red "Failed to fetch anixpkgs 2.1.1 by commit; received $(cat src2/ANIX_VERSION)"
    exit 1
fi
nix-build -E 'with (import (../../../default.nix) {}); pkgsSource { local = false; ref = "refs/heads/REGRESSION_TEST"; }' -o src3
if [[ -z $(cat src3/ANIX_VERSION | grep TEST_VERSION) ]]; then
    echo_red "Failed to fetch anixpkgs TEST_VERSION by branch; received $(cat src3/ANIX_VERSION)"
    exit 1
fi

make-title -c yellow "Clean up"
cd "$anixdir/test"
rm -rf $tmpdir

make-title -c green PASSED
