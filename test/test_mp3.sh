anixdir="$(dirname $PWD)"
export NIX_PATH="anixpkgs=$anixdir:$NIX_PATH"
tmpdir="$anixdir/test/tmpdir"
if [[ -d $tmpdir ]]; then
    rm -rf $tmpdir
fi
mkdir $tmpdir
cd $tmpdir

make-title -c yellow "Testing MP3 tools"

# WAV -> MP3
ffmpeg -f lavfi -i "sine=frequency=440:duration=2" -ar 44100 test.wav 2>/dev/null
mp3 test.wav wav_out.mp3
[[ -s wav_out.mp3 ]] || { echo_red "WAV to MP3 conversion produced no output"; exit 1; }
WAV_MP3_MD5=$(ckfile wav_out.mp3)
rm wav_out.mp3 && mp3 test.wav wav_out.mp3
ckfile -c $WAV_MP3_MD5 wav_out.mp3 || { echo_red "WAV to MP3 conversion is not deterministic"; exit 1; }

# WAV -> MP3 with transpose
mp3 --transpose +2 test.wav transposed_out.mp3
[[ -s transposed_out.mp3 ]] || { echo_red "WAV to MP3 transpose produced no output"; exit 1; }
TRANSPOSED_MD5=$(ckfile transposed_out.mp3)
rm transposed_out.mp3 && mp3 --transpose +2 test.wav transposed_out.mp3
ckfile -c $TRANSPOSED_MD5 transposed_out.mp3 || { echo_red "WAV to MP3 transpose is not deterministic"; exit 1; }

# MP4 -> MP3
ffmpeg -f lavfi -i "sine=frequency=440:duration=2" \
    -f lavfi -i "color=blue:s=64x64:rate=30" \
    -c:v libx264 -c:a libmp3lame -shortest test_audio.mp4 2>/dev/null
mp3 test_audio.mp4 mp4_out.mp3
[[ -s mp4_out.mp3 ]] || { echo_red "MP4 to MP3 conversion produced no output"; exit 1; }
MP4_MP3_MD5=$(ckfile mp4_out.mp3)
rm mp4_out.mp3 && mp3 test_audio.mp4 mp4_out.mp3
ckfile -c $MP4_MP3_MD5 mp4_out.mp3 || { echo_red "MP4 to MP3 conversion is not deterministic"; exit 1; }

# Cleanup
rm -rf "$tmpdir"
