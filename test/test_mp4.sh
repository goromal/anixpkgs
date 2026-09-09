anixdir="$(dirname $PWD)"
export NIX_PATH="anixpkgs=$anixdir:$NIX_PATH"
tmpdir="$anixdir/test/tmpdir"
if [[ -d $tmpdir ]]; then
    rm -rf $tmpdir
fi
mkdir $tmpdir
cd $tmpdir

make-title -c yellow "Testing MP4 tools"

mp4 4444-720-480-100.random my.mp4
EXPECTED_MD5=$(ckfile my.mp4)
rm my.mp4 && mp4 4444-720-480-100.random my.mp4
ckfile -c $EXPECTED_MD5 my.mp4 || { echo_red "Unexpected random MP4 hash"; exit 1; }
ckfile -c abcdefg my.mp4 && { echo_red "Unexpected random MP4 hash check"; exit 1; }

# Direct (non-vacuum) conversion still runs ffmpeg inline.
ffmpeg -f lavfi -i color=green:s=32x32:rate=5 -t 0.4 "$tmpdir/direct.flv" 2>/dev/null
mp4 "$tmpdir/direct.flv" "$tmpdir/direct.mp4"
[[ -s "$tmpdir/direct.mp4" ]] || { echo_red "direct flv conversion produced no output"; exit 1; }

# vacuum: dispatch an orchestrator conversion job per supported non-mp4 file,
# removing each source only once its conversion succeeds.
ORCH_PORT=6667
vacdir="$tmpdir/vac"
mkdir "$vacdir"
ffmpeg -f lavfi -i color=red:s=32x32:rate=5 -t 0.4 "$vacdir/clip.webm" 2>/dev/null
ffmpeg -f lavfi -i color=green:s=32x32:rate=5 -t 0.4 "$vacdir/reel.flv" 2>/dev/null
ffmpeg -f lavfi -i color=blue:s=32x32:rate=5 -t 0.4 "$vacdir/take.mov" 2>/dev/null
ffmpeg -f lavfi -i color=white:s=32x32:rate=5 -t 0.4 "$vacdir/keep.mp4" 2>/dev/null
# A source whose name contains whitespace, to prove the dispatched command
# survives orchestrator's argv splitting intact.
ffmpeg -f lavfi -i color=gray:s=32x32:rate=5 -t 0.4 "$vacdir/spaced name.mkv" 2>/dev/null
echo "not a video" > "$vacdir/notes.txt"

# vacuum aborts immediately when orchestrator is absent, touching nothing. The
# PATH is narrowed to coreutils/findutils so that the script's own helpers still
# resolve while orchestrator does not.
mp4bin="$(command -v mp4)"
noorch="$(dirname $(readlink -f $(command -v cat))):$(dirname $(readlink -f $(command -v find)))"
PATH="$noorch" "$mp4bin" vacuum "$vacdir" 2>/dev/null && { echo_red "vacuum ran without orchestrator on PATH"; exit 1; }
[[ -s "$vacdir/reel.flv" ]] || { echo_red "vacuum removed a source after failing its orchestrator check"; exit 1; }

nohup orchestratord -p $ORCH_PORT -n 2 > /dev/null 2>&1 &
serverPID=$!
sleep 4

# Conversion options are forwarded to every dispatched job, including ones
# whose values contain whitespace.
mp4 --orch-port $ORCH_PORT -m -q + --label "hello world" vacuum "$vacdir" \
    || { echo_red "vacuum failed to dispatch jobs"; kill $serverPID; exit 1; }

num_pending=1
num_tries=0
timeout_secs=60
while (( num_pending > 0 )) && (( num_tries < timeout_secs )); do
    num_pending=$(orchestrator -p $ORCH_PORT status count-pending)
    num_tries=$(( num_tries+1 ))
    sleep 1
done
if [ $num_pending -ne 0 ]; then
    echo_red "ERROR: vacuum jobs still pending after $timeout_secs seconds"
    kill $serverPID
    exit 1
fi

num_discarded=$(orchestrator -p $ORCH_PORT status count-discarded)
if [ $num_discarded -ne 0 ]; then
    echo_red "ERROR: vacuum finished with $num_discarded discarded jobs:"
    for jid in $(orchestrator -p $ORCH_PORT status get-discarded); do
        orchestrator -p $ORCH_PORT status $jid
    done
    kill $serverPID
    exit 1
fi
kill $serverPID

for stem in clip reel take "spaced name"; do
    [[ -s "$vacdir/$stem.mp4" ]] || { echo_red "vacuum did not produce $stem.mp4"; exit 1; }
done
for src in clip.webm reel.flv take.mov "spaced name.mkv"; do
    [[ -e "$vacdir/$src" ]] && { echo_red "vacuum left source $src behind"; exit 1; }
done
[[ -s "$vacdir/keep.mp4" ]] || { echo_red "vacuum consumed an existing mp4"; exit 1; }
[[ -s "$vacdir/notes.txt" ]] || { echo_red "vacuum consumed an unsupported file"; exit 1; }

# Cleanup
rm -rf "$tmpdir"
