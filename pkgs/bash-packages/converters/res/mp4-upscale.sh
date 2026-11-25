# Tool output goes to a log shown only on failure: orchestratord fails jobs on any stderr.

verbose=0
mute=0
stabilize=0
keep_color=0
quality=""
width=""
crop=""
start=""
end=""
label=""
fontsize="24"
model="fast"
gpu=""
host=""
while [[ $# -gt 0 ]]; do
    case "$1" in
    --verbose) verbose=1; shift ;;
    --mute) mute=1; shift ;;
    --stabilize) stabilize=1; shift ;;
    --keep-color) keep_color=1; shift ;;
    --quality) quality="$2"; shift 2 ;;
    --width) width="$2"; shift 2 ;;
    --crop) crop="$2"; shift 2 ;;
    --start) start="$2"; shift 2 ;;
    --end) end="$2"; shift 2 ;;
    --label) label="$2"; shift 2 ;;
    --fontsize) fontsize="$2"; shift 2 ;;
    --model) model="$2"; shift 2 ;;
    --gpu) gpu="$2"; shift 2 ;;
    --host) host="$2"; shift 2 ;;
    *) break ;;
    esac
done
if [[ $# -ne 3 ]]; then
    echo >&2 "usage: mp4-upscale [opts] classic|model INFILE OUTFILE"
    exit 1
fi
mode="$1"
infile="$2"
outfile="$3"
if [[ "$mode" != "classic" && "$mode" != "model" ]]; then
    echo >&2 "ERROR: unknown upscale mode '$mode' (expected classic or model)."
    exit 1
fi
if [[ ! -f "$infile" ]]; then
    echo >&2 "ERROR: input file not found ($infile)."
    exit 1
fi

case "$model" in
fast) model="realesr-animevideov3" ;;
quality) model="realesrgan-plus" ;;
esac

case "$quality" in
"" | "=") crf=18 ;;
"-") crf=22 ;;
"+") crf=15 ;;
*)
    echo >&2 "ERROR: unrecognized quality flag: $quality"
    exit 1
    ;;
esac

export PATH="$PATH:/run/current-system/sw/bin"

work="$(mktemp -d)"
log="$work/log"
touch "$log"
cleanup_cmds=()
cleanup() {
    for c in "${cleanup_cmds[@]}"; do eval "$c" > /dev/null 2>&1 || true; done
    rm -rf "$work"
}
trap cleanup EXIT

run() {
    echo "+ $*" >> "$log"
    if [[ "$verbose" == "1" ]]; then
        "$@" 2>&1 | tee -a "$log"
        return "${PIPESTATUS[0]}"
    fi
    "$@" >> "$log" 2>&1
}
fail() {
    echo >&2 "ERROR: $1"
    if [[ "$verbose" == "0" ]]; then
        echo >&2 "---- last lines of the log ----"
        tail -n 25 "$log" >&2
    fi
    exit 1
}
note() {
    if [[ "$verbose" == "1" ]]; then echo "$1"; fi
    echo "# $1" >> "$log"
}

if [[ "$mode" == "model" && -n "$host" ]]; then
    self="$(readlink -f "$0")"
    ext="${infile##*.}"
    note "Copying $self to $host..."
    run nix copy --no-check-sigs --to "ssh-ng://$host" "$self" || fail "could not copy mp4-upscale to $host."
    # Not /tmp: 4x intermediates are tens of GB.
    rdir="$(ssh -o BatchMode=yes "$host" 'mkdir -p ~/.cache/mp4-upscale && mktemp -d ~/.cache/mp4-upscale/job.XXXXXX' 2>> "$log")" \
        || fail "could not create a work directory on $host."
    cleanup_cmds+=("ssh -o BatchMode=yes $(printf %q "$host") rm -rf $(printf %q "$rdir")")
    note "Uploading $infile to $host:$rdir..."
    run scp -q -o BatchMode=yes "$infile" "$host:$rdir/in.$ext" || fail "could not upload $infile to $host."
    rargs=(--model "$model" --quality "${quality:-=}" --fontsize "$fontsize")
    [[ "$mute" == "1" ]] && rargs+=(--mute)
    [[ "$stabilize" == "1" ]] && rargs+=(--stabilize)
    [[ "$keep_color" == "1" ]] && rargs+=(--keep-color)
    [[ -n "$width" ]] && rargs+=(--width "$width")
    [[ -n "$crop" ]] && rargs+=(--crop "$crop")
    [[ -n "$start" ]] && rargs+=(--start "$start")
    [[ -n "$end" ]] && rargs+=(--end "$end")
    [[ -n "$label" ]] && rargs+=(--label "$label")
    [[ -n "$gpu" ]] && rargs+=(--gpu "$gpu")
    rcmd="$(printf '%q ' "$self" "${rargs[@]}" model "$rdir/in.$ext" "$rdir/out.mp4")"
    note "Running the model pipeline on $host..."
    if ! ssh -o BatchMode=yes "$host" "$rcmd" >> "$log" 2>&1; then
        fail "the model pipeline failed on $host."
    fi
    run scp -q -o BatchMode=yes "$host:$rdir/out.mp4" "$work/out.mp4" || fail "could not download the result from $host."
    mv "$work/out.mp4" "$outfile"
    exit 0
fi

probe() {
    ffprobe -v error -select_streams "$1" -show_entries "$2" -of default=nw=1:nk=1 "$infile" | head -n 1
}
src_w="$(probe v:0 stream=width)"
src_h="$(probe v:0 stream=height)"
sar="$(probe v:0 stream=sample_aspect_ratio)"
acodec="$(probe a:0 stream=codec_name || true)"
duration="$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$infile")"
[[ -n "$src_w" && -n "$src_h" ]] || fail "could not read the video size of $infile."
if [[ ! "$sar" =~ ^[0-9]+:[0-9]+$ || "$sar" == 0:* ]]; then sar="1:1"; fi

trim=()
[[ -n "$start" ]] && trim+=(-ss "$start")
[[ -n "$end" ]] && trim+=(-to "$end")

if [[ -z "$crop" ]]; then
    x1=$src_w; y1=$src_h; x2=0; y2=0
    for frac in 0.2 0.5 0.8; do
        at="$(awk -v d="$duration" -v f="$frac" 'BEGIN { printf "%.2f", d * f }')"
        vote="$(ffmpeg -hide_banner -nostdin -ss "$at" -i "$infile" -t 20 -an \
            -vf cropdetect=limit=40:round=2:reset=1 -f null - 2>&1 \
            | grep -o 'crop=[0-9]*:[0-9]*:[0-9]*:[0-9]*' | sort | uniq -c | sort -rn | head -n 1 \
            | sed -E 's/.*crop=//' || true)"
        [[ -n "$vote" ]] || continue
        IFS=: read -r vw vh vx vy <<< "$vote"
        ((vx < x1)) && x1=$vx
        ((vy < y1)) && y1=$vy
        ((vx + vw > x2)) && x2=$((vx + vw))
        ((vy + vh > y2)) && y2=$((vy + vh))
    done
    cw=$(((x2 - x1) / 2 * 2))
    ch=$(((y2 - y1) / 2 * 2))
    if ((cw > 0 && ch > 0 && cw * ch * 4 >= src_w * src_h * 3)); then
        crop="$cw:$ch:$x1:$y1"
    else
        crop="$src_w:$src_h:0:0"
    fi
fi
IFS=: read -r cw ch _ _ <<< "$crop"
note "Crop: $crop"

IFS=: read -r sar_n sar_d <<< "$sar"
if [[ -n "$width" ]]; then
    tw=$(((width / 2) * 2))
    th="$(awk -v w="$tw" -v cw="$cw" -v ch="$ch" -v n="$sar_n" -v d="$sar_d" \
        'BEGIN { printf "%d", int(w * ch * d / (cw * n) / 2 + 0.5) * 2 }')"
else
    th=1080
    tw="$(awk -v h="$th" -v cw="$cw" -v ch="$ch" -v n="$sar_n" -v d="$sar_d" \
        'BEGIN { printf "%d", int(h * cw * n / (ch * d) / 2 + 0.5) * 2 }')"
fi
note "Target: ${tw}x${th}"

note "Analyzing chroma alignment and white balance..."
mp4-upscale-analyze "$infile" "$crop" "$start" "$end" "$work/wb.cmd" > "$work/analysis" 2>> "$log" \
    || fail "color analysis failed."
read -r _ chroma_h chroma_v < "$work/analysis"
note "Chroma offset: ${chroma_h}px horizontal, ${chroma_v}px vertical"

front="crop=$crop"
if [[ "$chroma_h" != "0" || "$chroma_v" != "0" ]]; then
    front="$front,format=yuv444p,chromashift=cbh=$((-chroma_h)):crh=$((-chroma_h)):cbv=$((-chroma_v)):crv=$((-chroma_v))"
fi
if [[ "$stabilize" == "1" ]]; then
    note "Stabilization pass 1/2..."
    run ffmpeg -hide_banner -nostdin -y "${trim[@]}" -i "$infile" -an \
        -vf "$front,vidstabdetect=shakiness=6:accuracy=12:result=$work/motion.trf" -f null - \
        || fail "stabilization analysis failed."
    front="$front,vidstabtransform=input=$work/motion.trf:smoothing=15:optzoom=1:interpol=bicubic"
fi
if [[ "$keep_color" == "0" ]]; then
    front="$front,format=gbrp,sendcmd=f=$work/wb.cmd,colorchannelmixer@wb"
fi
front="$front,format=yuv420p"

tail_filters="scale=$tw:$th:flags=lanczos,setsar=1"
if [[ -n "$label" ]]; then
    tail_filters="$tail_filters,drawtext=fontfile=$MP4_UPSCALE_FONT:text=$label:fontcolor=white:fontsize=$fontsize:box=1:boxcolor=black@0.75:boxborderw=10:x=10:y=h-text_h-10"
fi

audio=()
if [[ "$mute" == "1" ]]; then
    audio=(-an)
elif [[ -z "$acodec" ]]; then
    audio=()
elif [[ "$acodec" == "aac" ]]; then
    audio=(-map "0:a:0" -c:a copy)
else
    audio=(-map "0:a:0" -c:a aac -b:a 192k)
fi
encode=(-c:v libx264 -preset medium -crf "$crf" -pix_fmt yuv420p -movflags +faststart)

if [[ "$mode" == "classic" ]]; then
    note "Restoring and upscaling..."
    run ffmpeg -hide_banner -nostdin -y "${trim[@]}" -i "$infile" -map 0:v:0 "${audio[@]}" \
        -vf "$front,hqdn3d=3:3:6:6,deblock=filter=weak:block=8,$tail_filters,cas=0.5" \
        "${encode[@]}" "$work/out.mp4" || fail "classic upscale failed."
    mv "$work/out.mp4" "$outfile"
    exit 0
fi

if command -v video2x > /dev/null 2>&1; then
    v2x=(video2x)
else
    v2x=(nix shell nixpkgs#video2x -c video2x)
fi

# video2x -d takes ncnn's device index, whose order differs from video2x -l.
if [[ -z "$gpu" ]]; then
    run ffmpeg -hide_banner -nostdin -y -f lavfi -i color=gray:s=64x64:rate=1 -t 1 "$work/probe.mp4" \
        || fail "could not create the GPU probe clip."
    "${v2x[@]}" --no-progress --log-level error -i "$work/probe.mp4" -o "$work/probe-out.mp4" \
        -p realesrgan -s 2 --realesrgan-model realesr-animevideov3 < /dev/null > "$work/gpus" 2>&1 || true
    cat "$work/gpus" >> "$log"
    gpu="$(grep -E '^\[[0-9]+ ' "$work/gpus" | grep -iE 'nvidia|amd|radeon' | head -n 1 | sed -E 's/^\[([0-9]+) .*/\1/' || true)"
    if [[ -z "$gpu" ]]; then
        gpu="$(grep -E '^\[[0-9]+ ' "$work/gpus" | grep -viE 'llvmpipe' | head -n 1 | sed -E 's/^\[([0-9]+) .*/\1/' || true)"
    fi
    [[ -n "$gpu" ]] || fail "no Vulkan GPU found for the model pass (see log)."
fi
note "Using ncnn GPU index $gpu, model $model"

# video2x's stream copy drifts audio, so it is muxed from the source instead.
note "Preparing model input..."
run ffmpeg -hide_banner -nostdin -y "${trim[@]}" -i "$infile" -map 0:v:0 -an \
    -vf "$front,setsar=1" -c:v libx264 -preset veryfast -crf 10 "$work/pre.mkv" \
    || fail "could not prepare the model input."

note "Running $model (4x)..."
run "${v2x[@]}" --no-progress --log-level warn -d "$gpu" -i "$work/pre.mkv" -o "$work/up.mkv" \
    -p realesrgan -s 4 --realesrgan-model "$model" -e preset=veryfast -e crf=14 < /dev/null \
    || fail "video2x failed."
rm -f "$work/pre.mkv"

note "Resizing to ${tw}x${th}..."
post_audio=()
if [[ "${#audio[@]}" -gt 1 ]]; then
    post_audio=("${trim[@]}" -i "$infile" -map "1:a:0" "${audio[@]:2}" -shortest)
fi
run ffmpeg -hide_banner -nostdin -y -i "$work/up.mkv" "${post_audio[@]}" -map 0:v:0 \
    -vf "$tail_filters" "${encode[@]}" "$work/out.mp4" || fail "final encode failed."
mv "$work/out.mp4" "$outfile"
