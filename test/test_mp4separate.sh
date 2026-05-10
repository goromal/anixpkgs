anixdir="$(dirname $PWD)"
export NIX_PATH="anixpkgs=$anixdir:$NIX_PATH"
tmpdir="$anixdir/test/tmpdir"
if [[ -d $tmpdir ]]; then
    rm -rf $tmpdir
fi
mkdir $tmpdir
cd $tmpdir

make-title -c yellow "Testing mp4separate"

# Generate two test MP4 files:
#   source_kf.mp4 - keyframe every second (simulates streaming-optimized file)
#   source_nokf.mp4 - large GOP (simulates camera/edited file with sparse keyframes)
ffmpeg -f lavfi -i "sine=frequency=440:duration=6" \
    -f lavfi -i "color=blue:s=64x64:rate=30:duration=6" \
    -c:v libx264 -g 30 -c:a libmp3lame -shortest source_kf.mp4 2>/dev/null
[[ -s source_kf.mp4 ]] || { echo_red "Failed to generate source_kf.mp4"; exit 1; }

ffmpeg -f lavfi -i "sine=frequency=440:duration=6" \
    -f lavfi -i "color=blue:s=64x64:rate=30:duration=6" \
    -c:v libx264 -g 300 -c:a libmp3lame -shortest source_nokf.mp4 2>/dev/null
[[ -s source_nokf.mp4 ]] || { echo_red "Failed to generate source_nokf.mp4"; exit 1; }

# mp4separate: stream-copy split by number of segments on keyframe-friendly file
mp4separate --num-segments 3 source_kf.mp4
seg_count=$(ls source_kf_0*.mp4 2>/dev/null | wc -l)
[[ "$seg_count" -ge 3 && "$seg_count" -le 4 ]] || { echo_red "mp4separate --num-segments 3 produced $seg_count segments, expected 3-4"; exit 1; }
rm -f source_kf_0*.mp4

# mp4separate: stream-copy split by segment length on keyframe-friendly file
mp4separate --seg-length 00:02 source_kf.mp4
seg_count=$(ls source_kf_0*.mp4 2>/dev/null | wc -l)
[[ "$seg_count" -ge 3 ]] || { echo_red "mp4separate --seg-length 00:02 produced $seg_count segments, expected >=3"; exit 1; }
rm -f source_kf_0*.mp4

# mp4separate: --reencode forces precise splits regardless of keyframe interval
mp4separate --reencode --num-segments 3 source_nokf.mp4
seg_count=$(ls source_nokf_0*.mp4 2>/dev/null | wc -l)
[[ "$seg_count" -ge 3 && "$seg_count" -le 4 ]] || { echo_red "mp4separate --reencode --num-segments 3 produced $seg_count segments, expected 3-4"; exit 1; }
rm -f source_nokf_0*.mp4

mp4separate --reencode --seg-length 00:02 source_nokf.mp4
seg_count=$(ls source_nokf_0*.mp4 2>/dev/null | wc -l)
[[ "$seg_count" -ge 3 ]] || { echo_red "mp4separate --reencode --seg-length 00:02 produced $seg_count segments, expected >=3"; exit 1; }
rm -f source_nokf_0*.mp4

# mp4separate: rejects both options simultaneously
mp4separate --num-segments 2 --seg-length 00:02 source_kf.mp4 2>/dev/null && { echo_red "mp4separate should reject both --num-segments and --seg-length"; exit 1; }

# mp4separate: rejects neither option
mp4separate source_kf.mp4 2>/dev/null && { echo_red "mp4separate should require --num-segments or --seg-length"; exit 1; }

# mp4separate: rejects invalid segment length format
mp4separate --seg-length 90 source_kf.mp4 2>/dev/null && { echo_red "mp4separate should reject invalid --seg-length format"; exit 1; }

# mp4separate: rejects non-mp4 input
mp4separate --num-segments 2 source.mp3 2>/dev/null && { echo_red "mp4separate should reject non-mp4 input"; exit 1; }

# mp4separate: rejects missing source file
mp4separate --num-segments 2 nonexistent.mp4 2>/dev/null && { echo_red "mp4separate should fail on missing source"; exit 1; }

# Cleanup
rm -rf "$tmpdir"
