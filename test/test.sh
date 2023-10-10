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

make-title -c yellow "Testing orchestrator"
mkdir orch_data
orchoutpath="$tmpdir/orch_data"

num_server_threads=2

echo "Spawning server with $num_server_threads threads"

nohup orchestratord -n $num_server_threads > /dev/null 2>&1 &
serverPID=$!

sleep 4

echo "Spawning jobs"

dljob=$(orchestrator scrape https://filesamples.com/formats/webm body/div webm $orchoutpath)
rmjob=$(orchestrator remove -b $dljob $orchoutpath/sample_960x400_ocean_with_audio.webm)
rmjob=$(orchestrator remove -b $rmjob $orchoutpath/sample_1280x720.webm)
rmjob=$(orchestrator remove -b $rmjob $orchoutpath/sample_1920x1080.webm)
rmjob=$(orchestrator remove -b $rmjob $orchoutpath/sample_2560x1440.webm)
rmjob=$(orchestrator remove -b $rmjob $orchoutpath/sample_3840x2160.webm)
lsjob=$(orchestrator listing -b $rmjob --ext webm $orchoutpath)
mp4job=$(orchestrator mp4 $lsjob $orchoutpath/vid.mp4)
rmjob=$(orchestrator remove $lsjob -b $mp4job)
unijob=$(orchestrator mp4-unite $mp4job $orchoutpath/unified_vid.mp4)
rmjob=$(orchestrator remove $mp4job -b $unijob)

num_pending=1
timeout_secs=60
num_tries=0

echo "Waiting for pending jobs..."

while (( num_pending > 0 )) && (( num_tries < timeout_secs )); do
    num_pending=$(orchestrator status count-pending)
    num_tries=$(( num_tries+1 ))
    sleep 1
done

if [ $num_pending -ne 0 ]; then
    echo_red "ERROR: orchestrator timed out at $timeout_secs seconds with $num_pending unfinished jobs:"
    orchestrator status all
    kill $serverPID
    exit 1
fi

echo "All jobs complete at $num_tries seconds"

if [ ! -f "$orchoutpath/unified_vid.mp4" ]; then
    echo_red "ERROR: expected workflow output not present"
    kill $serverPID
    exit 1
fi

num_outputs=$(ls -1 "$orchoutpath" | wc -l)
if [ $num_outputs -ne 1 ]; then
    echo_red "ERROR: extra outputs present"
    kill $serverPID
    exit 1
fi

echo "Passed, killing server"
kill $serverPID

make-title -c yellow "Clean up"
cd "$anixdir/test"
rm -rf $tmpdir

make-title -c green PASSED
