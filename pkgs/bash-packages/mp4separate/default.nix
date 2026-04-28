{
  writeArgparseScriptBin,
  color-prints,
  strings,
  ffmpeg,
}:
let
  pkgname = "mp4separate";
  printErr = "${color-prints}/bin/echo_red";
in
(writeArgparseScriptBin pkgname
  ''
    usage: ${pkgname} [options] <MP4-sourcefile>

    Split an MP4 file into segments.

    By default, splits via stream copy (fast, lossless) which snaps cuts to the
    nearest keyframe. Use --reencode for precise cuts at the cost of speed and
    a re-encode.

    Options:
    -h | --help          Print out the help documentation.
    -n | --num-segments  Split into N equally sized segments.
    -l | --seg-length    Split into segments of length MM:SS (e.g. 01:30).
    -r | --reencode      Re-encode with forced keyframes for precise splits.
    -v | --verbose       Print verbose output from ffmpeg
  ''
  [
    {
      var = "num_segments";
      isBool = false;
      default = "";
      flags = "-n|--num-segments";
    }
    {
      var = "seg_length";
      isBool = false;
      default = "";
      flags = "-l|--seg-length";
    }
    {
      var = "reencode";
      isBool = true;
      default = "0";
      flags = "-r|--reencode";
    }
    {
      var = "verbose";
      isBool = true;
      default = "0";
      flags = "-v|--verbose";
    }
  ]
  ''
    if [ "$#" -lt "1" ]; then
        ${printErr} "Must provide a source MP4 file"
        exit 1
    fi
    sourcefile="$1"
    fileargext=`${strings.getExtension} "$sourcefile"`
    if [[ "$fileargext" != "mp4" && "$fileargext" != "MP4" ]]; then
        ${printErr} "Source file does not have an mp4 extension: $sourcefile"
        exit 1
    fi
    if [[ ! -f "$sourcefile" ]]; then
        ${printErr} "Source file does not exist: $sourcefile"
        exit 1
    fi
    if [[ -z "$num_segments" && -z "$seg_length" ]]; then
        ${printErr} "Must specify either --num-segments or --seg-length"
        exit 1
    fi
    if [[ -n "$num_segments" && -n "$seg_length" ]]; then
        ${printErr} "Cannot specify both --num-segments and --seg-length"
        exit 1
    fi

    basename_noext=`${strings.getWithoutExtension} "$sourcefile"`

    ffmpeg_verbose_flag=""
    if [[ "$verbose" == "0" ]]; then
        ffmpeg_verbose_flag="-loglevel error"
    fi

    total_dur=$(${ffmpeg}/bin/ffprobe -v error -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 "$sourcefile")

    if [[ -n "$num_segments" ]]; then
        if ! [[ "$num_segments" =~ ^[1-9][0-9]*$ ]]; then
            ${printErr} "--num-segments must be a positive integer"
            exit 1
        fi
        seg_dur=$(awk "BEGIN{printf \"%.6f\", $total_dur / $num_segments}")
    else
        if ! [[ "$seg_length" =~ ^[0-9]+:[0-5][0-9]$ ]]; then
            ${printErr} "--seg-length must be in MM:SS format (e.g. 01:30)"
            exit 1
        fi
        minutes="''${seg_length%%:*}"
        seconds="''${seg_length##*:}"
        seg_dur=$(( 10#$minutes * 60 + 10#$seconds ))
        if [[ "$seg_dur" -eq 0 ]]; then
            ${printErr} "--seg-length must be greater than 00:00"
            exit 1
        fi
    fi

    if [[ "$reencode" == "1" ]]; then
        # Run one ffmpeg call per segment with -ss/-to for precise seeking.
        # The segment muxer cannot reliably cut at forced keyframes, so we
        # re-encode each slice independently instead.
        i=0
        t=0
        while awk "BEGIN{exit !($t < $total_dur - 0.001)}"; do
            end=$(awk "BEGIN{printf \"%.6f\", $t + $seg_dur}")
            outfile="''${basename_noext}_$(printf '%03d' $i).mp4"
            if awk "BEGIN{exit !($end >= $total_dur)}"; then
                ${ffmpeg}/bin/ffmpeg $ffmpeg_verbose_flag \
                    -ss "$t" -i "$sourcefile" \
                    -c:v libx264 -c:a aac "$outfile"
            else
                ${ffmpeg}/bin/ffmpeg $ffmpeg_verbose_flag \
                    -ss "$t" -to "$end" -i "$sourcefile" \
                    -c:v libx264 -c:a aac "$outfile"
            fi
            t=$end
            (( i++ ))
        done
    else
        ${ffmpeg}/bin/ffmpeg $ffmpeg_verbose_flag -i "$sourcefile" \
            -f segment -segment_time "$seg_dur" -c copy \
            "''${basename_noext}_%03d.mp4"
    fi
  ''
)
// {
  meta = {
    description = "Split an MP4 file into N equal segments or segments of a given length.";
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
