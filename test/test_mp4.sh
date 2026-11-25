anixdir="$(dirname $PWD)"
export NIX_PATH="anixpkgs=$anixdir:$NIX_PATH"
tmpdir="${TEST_TMPDIR:-$anixdir/test/tmpdir}"
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

# Model-only upscale options are rejected rather than silently ignored.
mp4 --gpu 1 "$tmpdir/direct.flv" "$tmpdir/x.mp4" > /dev/null 2>&1 && { echo_red "--gpu accepted without --upscale"; exit 1; }
mp4 -u classic --host nowhere "$tmpdir/direct.flv" "$tmpdir/x.mp4" > /dev/null 2>&1 && { echo_red "--host accepted with --upscale classic"; exit 1; }
mp4 -u bogus "$tmpdir/direct.flv" "$tmpdir/x.mp4" > /dev/null 2>&1 && { echo_red "unknown upscale mode accepted"; exit 1; }

# Cleanup
rm -rf "$tmpdir"
