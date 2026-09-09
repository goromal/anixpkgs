anixdir="$(dirname $PWD)"
export NIX_PATH="anixpkgs=$anixdir:$NIX_PATH"
tmpdir="$anixdir/test/tmpdir"
if [[ -d $tmpdir ]]; then
    rm -rf $tmpdir
fi
mkdir $tmpdir
cd $tmpdir

make-title -c yellow "Testing converter vacuum"

serverPID=""
fail() {
    echo_red "$1"
    [[ -n "$serverPID" ]] && kill $serverPID 2>/dev/null
    exit 1
}

mkvid() { ffmpeg -f lavfi -i color=$2:s=32x32:rate=5 -t 0.4 "$1" 2>/dev/null; }

# Wait for the daemon to drain, then report how many jobs it threw away.
drain() {
    local port=$1 pending=1 tries=0
    while (( pending > 0 )) && (( tries < 60 )); do
        pending=$(orchestrator -p $port status count-pending)
        tries=$(( tries+1 ))
        sleep 1
    done
    (( pending == 0 )) || return 1
    orchestrator -p $port status count-discarded
}

########################################################################
# Guards, none of which need a running daemon.
########################################################################
guarddir="$tmpdir/guard"
mkdir "$guarddir"
mkvid "$guarddir/clip.webm" red

# Vacuum aborts when orchestrator is absent, without touching anything. PATH is
# narrowed to coreutils/findutils so the script's own helpers still resolve.
mp4bin="$(command -v mp4)"
noorch="$(dirname $(readlink -f $(command -v cat))):$(dirname $(readlink -f $(command -v find)))"
PATH="$noorch" "$mp4bin" vacuum "$guarddir" 2>/dev/null \
    && fail "vacuum ran with no orchestrator on PATH"
[[ -s "$guarddir/clip.webm" ]] || fail "vacuum touched a source before its orchestrator check"

mp4 vacuum 2>/dev/null && fail "vacuum accepted a missing directory argument"
mp4 vacuum "$tmpdir/nonexistent" 2>/dev/null && fail "vacuum accepted a nonexistent directory"
mp4 vacuum "$guarddir/clip.webm" 2>/dev/null && fail "vacuum accepted a file as its directory"

emptydir="$tmpdir/empty"
mkdir "$emptydir"
mp4 vacuum "$emptydir" > "$tmpdir/empty.out" 2>&1 || fail "vacuum errored on an empty directory"
grep -q "No files with supported extensions" "$tmpdir/empty.out" \
    || fail "vacuum did not report an empty directory"

########################################################################
# Successful sweep.
########################################################################
ORCH_PORT=6668
nohup orchestratord -p $ORCH_PORT -n 2 > /dev/null 2>&1 &
serverPID=$!
sleep 4

vacdir="$tmpdir/vac"
mkdir "$vacdir"
mkvid "$vacdir/clip.webm" red
mkvid "$vacdir/reel.flv" green
mkvid "$vacdir/take.mov" blue
mkvid "$vacdir/keep.mp4" white
# Whitespace in a source name must survive orchestrator's argv splitting.
mkvid "$vacdir/spaced name.mkv" gray
echo "not a video" > "$vacdir/notes.txt"

# Every converter option applies to dispatched work, including values that
# contain whitespace.
mp4 --orch-port $ORCH_PORT -m -q + --label "hello world" vacuum "$vacdir" \
    || fail "vacuum failed to dispatch jobs"

discarded=$(drain $ORCH_PORT) || fail "vacuum jobs never drained"
[[ "$discarded" == "0" ]] || fail "sweep discarded $discarded job(s); expected 0"

for stem in clip reel take "spaced name"; do
    [[ -s "$vacdir/$stem.mp4" ]] || fail "vacuum did not produce $stem.mp4"
done
for src in clip.webm reel.flv take.mov "spaced name.mkv"; do
    [[ -e "$vacdir/$src" ]] && fail "vacuum left source $src behind"
done
# The output extension is excluded from mp4's sweep, and unsupported files are
# never touched.
[[ -s "$vacdir/keep.mp4" ]] || fail "vacuum consumed an existing mp4"
[[ -s "$vacdir/notes.txt" ]] || fail "vacuum consumed an unsupported file"

########################################################################
# Verbosity is not forwarded: the daemon reads any stderr output as failure,
# so a forwarded -v would turn every successful conversion into an error.
########################################################################
vdir="$tmpdir/verbose"
mkdir "$vdir"
mkvid "$vdir/loud.webm" red

mp4 --orch-port $ORCH_PORT -v vacuum "$vdir" > "$tmpdir/verbose.out" 2>&1 \
    || fail "vacuum failed to dispatch with -v"
grep -q "does not apply to vacuum" "$tmpdir/verbose.out" \
    || fail "vacuum did not warn that -v is ignored"

discarded=$(drain $ORCH_PORT) || fail "verbose jobs never drained"
[[ "$discarded" == "0" ]] || fail "-v produced $discarded discarded job(s); expected 0"
[[ -s "$vdir/loud.mp4" ]] || fail "vacuum did not convert loud.webm"
[[ -e "$vdir/loud.webm" ]] && fail "vacuum left loud.webm behind"

kill $serverPID
serverPID=""

########################################################################
# A failed conversion must not cost the source file. Run against a fresh
# daemon so the expected discards are counted in isolation.
########################################################################
FAIL_PORT=6669
nohup orchestratord -p $FAIL_PORT -n 2 > /dev/null 2>&1 &
serverPID=$!
sleep 4

faildir="$tmpdir/failing"
mkdir "$faildir"
# A supported extension whose contents are not decodable: ffmpeg exits non-zero
# and, in non-verbose mode, writes nothing to stderr.
printf 'this is definitely not a matroska file' > "$faildir/corrupt.mkv"
mkvid "$faildir/fine.webm" red

mp4 --orch-port $FAIL_PORT vacuum "$faildir" || fail "vacuum failed to dispatch mixed jobs"

discarded=$(drain $FAIL_PORT) || fail "mixed jobs never drained"
# The corrupt conversion errors, and the removal blocked on it is canceled.
[[ "$discarded" == "2" ]] || fail "expected 2 discarded jobs for one failure, got $discarded"

[[ -s "$faildir/corrupt.mkv" ]] || fail "vacuum deleted the source of a FAILED conversion"
[[ -e "$faildir/corrupt.mp4" ]] && fail "a failed conversion left output behind"
# The healthy file in the same sweep is unaffected.
[[ -s "$faildir/fine.mp4" ]] || fail "vacuum did not convert fine.webm"
[[ -e "$faildir/fine.webm" ]] && fail "vacuum left fine.webm behind"

kill $serverPID
serverPID=""

########################################################################
# A converter that produces nothing must not be reported as a success, or
# vacuum would delete sources for conversions that never happened.
########################################################################
stubdir="$tmpdir/stub"
mkdir "$stubdir"
echo "some text" > "$stubdir/notes.md"
gif "$stubdir/notes.md" "$stubdir/notes.gif" 2>/dev/null \
    && fail "an unimplemented converter reported success"
[[ -e "$stubdir/notes.gif" ]] && fail "an unimplemented converter produced output"

# Cleanup
rm -rf "$tmpdir"
