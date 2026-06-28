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

# vacuum: convert every supported file in a directory, preserving filenames
vacdir="$tmpdir/vac"
mkdir "$vacdir"
ffmpeg -f lavfi -i color=red:s=32x32:rate=5 -t 0.4 "$vacdir/clip.webm" 2>/dev/null
echo "not a video" > "$vacdir/notes.txt"
mp4 vacuum "$vacdir"
[[ -s "$vacdir/clip.mp4" ]] || { echo_red "vacuum did not convert clip.webm"; exit 1; }
[[ -f "$vacdir/notes.mp4" ]] && { echo_red "vacuum converted an unsupported file"; exit 1; }

# Cleanup
rm -rf "$tmpdir"
