anixdir="$(dirname $PWD)"
export NIX_PATH="anixpkgs=$anixdir:$NIX_PATH"
tmpdir="$anixdir/test/tmpdir"
if [[ -d $tmpdir ]]; then
    rm -rf $tmpdir
fi
mkdir $tmpdir
cd $tmpdir

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

scrape --xpath body --ext webm --output $orchoutpath simple-link-scraper https://goromal.github.io/anixpkgs/python/scrape.html
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

# Cleanup
kill $serverPID
rm -rf "$tmpdir"
