anixdir="$(dirname $PWD)"
export NIX_PATH="anixpkgs=$anixdir:$NIX_PATH"
tmpdir="$anixdir/test/tmpdir"
if [[ -d $tmpdir ]]; then
    rm -rf $tmpdir
fi
mkdir $tmpdir
cd $tmpdir

make-title -c yellow "Testing PNG tools"

# Random PNG generation (determinism check)
png 4444-400-200.random my.png
ckfile -c 5ccd6f61bddaae29a2c2b56a1561a1dd my.png || { echo_red "Unexpected random PNG hash"; exit 1; }
ckfile -c 5ccd6f61bddaae29da2c2b56a1561a1dd my.png && { echo_red "Unexpected random PNG hash check"; exit 1; }

# GIF -> PNG
ffmpeg -f lavfi -i color=red:s=20x20:rate=5 -t 0.4 test.gif 2>/dev/null
png test.gif gif_out.png
[[ -s gif_out.png ]] || { echo_red "GIF to PNG conversion produced no output"; exit 1; }
GIF_PNG_MD5=$(ckfile gif_out.png)
rm gif_out.png && png test.gif gif_out.png
ckfile -c $GIF_PNG_MD5 gif_out.png || { echo_red "GIF to PNG conversion is not deterministic"; exit 1; }

# SVG -> PNG
cat > test.svg << 'SVGEOF'
<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20"><rect width="20" height="20" fill="blue"/></svg>
SVGEOF
png test.svg svg_out.png
[[ -s svg_out.png ]] || { echo_red "SVG to PNG conversion produced no output"; exit 1; }
SVG_PNG_MD5=$(ckfile svg_out.png)
rm svg_out.png && png test.svg svg_out.png
ckfile -c $SVG_PNG_MD5 svg_out.png || { echo_red "SVG to PNG conversion is not deterministic"; exit 1; }

# vacuum: dispatch a conversion per supported file, preserving filenames.
# Filenames deliberately include spaces and extra dots to lock in that only the
# final extension is replaced (the rest of the name is preserved verbatim).
# Conversions run as orchestrator jobs, so the sweep has to be drained before
# its results can be inspected.
ORCH_PORT=6670
vacdir="$tmpdir/vac"
mkdir "$vacdir"
ffmpeg -f lavfi -i color=red:s=20x20:rate=5 -t 0.4 "$vacdir/my clip.v2.gif" 2>/dev/null
cat > "$vacdir/pic.svg" << 'SVGEOF'
<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20"><rect width="20" height="20" fill="blue"/></svg>
SVGEOF
echo "not an image" > "$vacdir/notes.txt"

nohup orchestratord -p $ORCH_PORT -n 2 > /dev/null 2>&1 &
serverPID=$!
sleep 4
png --orch-port $ORCH_PORT vacuum "$vacdir" || { echo_red "vacuum failed to dispatch jobs"; kill $serverPID; exit 1; }

num_pending=1
num_tries=0
while (( num_pending > 0 )) && (( num_tries < 60 )); do
    num_pending=$(orchestrator -p $ORCH_PORT status count-pending)
    num_tries=$(( num_tries+1 ))
    sleep 1
done
num_discarded=$(orchestrator -p $ORCH_PORT status count-discarded)
kill $serverPID
[[ "$num_pending" == "0" ]] || { echo_red "vacuum jobs never drained"; exit 1; }
[[ "$num_discarded" == "0" ]] || { echo_red "vacuum discarded $num_discarded job(s)"; exit 1; }

[[ -s "$vacdir/my clip.v2.png" ]] || { echo_red "vacuum did not preserve filename converting gif -> png"; exit 1; }
[[ -s "$vacdir/pic.png" ]] || { echo_red "vacuum did not convert pic.svg"; exit 1; }
[[ -f "$vacdir/notes.png" ]] && { echo_red "vacuum converted an unsupported file"; exit 1; }
[[ -f "$vacdir/notes.txt" ]] || { echo_red "vacuum removed an unsupported file"; exit 1; }
# Sources are consumed once their conversions succeed.
[[ -e "$vacdir/my clip.v2.gif" ]] && { echo_red "vacuum left a converted source behind"; exit 1; }
[[ -e "$vacdir/pic.svg" ]] && { echo_red "vacuum left a converted source behind"; exit 1; }

# Cleanup
rm -rf "$tmpdir"
