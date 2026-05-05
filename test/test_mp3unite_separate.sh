anixdir="$(dirname $PWD)"
export NIX_PATH="anixpkgs=$anixdir:$NIX_PATH"
tmpdir="$anixdir/test/tmpdir"
if [[ -d $tmpdir ]]; then
    rm -rf $tmpdir
fi
mkdir $tmpdir
cd $tmpdir

make-title -c yellow "Testing mp3unite and mp3separate"

# Generate two short MP3 test files
ffmpeg -f lavfi -i "sine=frequency=440:duration=3" -ar 44100 part1.mp3 2>/dev/null
ffmpeg -f lavfi -i "sine=frequency=880:duration=3" -ar 44100 part2.mp3 2>/dev/null
[[ -s part1.mp3 ]] || { echo_red "Failed to generate part1.mp3"; exit 1; }
[[ -s part2.mp3 ]] || { echo_red "Failed to generate part2.mp3"; exit 1; }

# mp3unite: basic join
mp3unite part1.mp3 part2.mp3 joined.mp3
[[ -s joined.mp3 ]] || { echo_red "mp3unite produced no output"; exit 1; }

# mp3unite: joined file should be larger than either source
size_part1=$(wc -c < part1.mp3)
size_joined=$(wc -c < joined.mp3)
[[ "$size_joined" -gt "$size_part1" ]] || { echo_red "mp3unite output is not larger than a single source file"; exit 1; }

# mp3unite: deterministic output
UNITE_MD5=$(ckfile joined.mp3)
rm joined.mp3 && mp3unite part1.mp3 part2.mp3 joined.mp3
ckfile -c $UNITE_MD5 joined.mp3 || { echo_red "mp3unite output is not deterministic"; exit 1; }

# mp3unite: rejects non-mp3 argument
mp3unite part1.mp3 part2.mp3 out.wav 2>/dev/null && { echo_red "mp3unite should reject non-mp3 destination"; exit 1; }
mp3unite part1.mp3 notanmp3.txt joined2.mp3 2>/dev/null && { echo_red "mp3unite should reject non-mp3 source"; exit 1; }

# mp3unite: rejects missing source file
mp3unite part1.mp3 nonexistent.mp3 joined2.mp3 2>/dev/null && { echo_red "mp3unite should fail on missing source"; exit 1; }

# mp3separate: split by number of segments (allow one extra trailing fragment)
mp3separate --num-segments 3 joined.mp3
seg_count=$(ls joined_0*.mp3 2>/dev/null | wc -l)
[[ "$seg_count" -ge 3 && "$seg_count" -le 4 ]] || { echo_red "mp3separate --num-segments 3 produced $seg_count segments, expected 3-4"; exit 1; }
rm -f joined_0*.mp3

# mp3separate: split by segment length
mp3separate --seg-length 00:02 joined.mp3
seg_count=$(ls joined_0*.mp3 2>/dev/null | wc -l)
[[ "$seg_count" -ge 3 ]] || { echo_red "mp3separate --seg-length 00:02 produced $seg_count segments, expected >=3"; exit 1; }
rm -f joined_0*.mp3

# mp3separate: rejects both options simultaneously
mp3separate --num-segments 2 --seg-length 00:02 joined.mp3 2>/dev/null && { echo_red "mp3separate should reject both --num-segments and --seg-length"; exit 1; }

# mp3separate: rejects neither option
mp3separate joined.mp3 2>/dev/null && { echo_red "mp3separate should require --num-segments or --seg-length"; exit 1; }

# mp3separate: rejects invalid segment length format
mp3separate --seg-length 90 joined.mp3 2>/dev/null && { echo_red "mp3separate should reject invalid --seg-length format"; exit 1; }

# mp3separate: rejects non-mp3 input
mp3separate --num-segments 2 part1.wav 2>/dev/null && { echo_red "mp3separate should reject non-mp3 input"; exit 1; }

# Cleanup
rm -rf "$tmpdir"
