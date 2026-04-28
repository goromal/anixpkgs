{
  writeArgparseScriptBin,
  color-prints,
  strings,
  ffmpeg,
}:
let
  pkgname = "mp3separate";
  printErr = "${color-prints}/bin/echo_red";
in
(writeArgparseScriptBin pkgname
  ''
    usage: ${pkgname} [options] <MP3-sourcefile>

    Split an MP3 file into segments.

    Options:
    -h | --help          Print out the help documentation.
    -n | --num-segments  Split into N equally sized segments.
    -l | --seg-length    Split into segments of length MM:SS (e.g. 01:30).
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
      var = "verbose";
      isBool = true;
      default = "0";
      flags = "-v|--verbose";
    }
  ]
  ''
    if [ "$#" -lt "1" ]; then
        ${printErr} "Must provide a source MP3 file"
        exit 1
    fi
    sourcefile="$1"
    fileargext=`${strings.getExtension} "$sourcefile"`
    if [[ "$fileargext" != "mp3" && "$fileargext" != "MP3" ]]; then
        ${printErr} "Source file does not have an mp3 extension: $sourcefile"
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

    if [[ -n "$num_segments" ]]; then
        if ! [[ "$num_segments" =~ ^[1-9][0-9]*$ ]]; then
            ${printErr} "--num-segments must be a positive integer"
            exit 1
        fi
        # Compute total duration in seconds using ffprobe
        total_dur=$(${ffmpeg}/bin/ffprobe -v error -show_entries format=duration \
            -of default=noprint_wrappers=1:nokey=1 "$sourcefile")
        seg_dur=$(echo "$total_dur $num_segments" | awk '{printf "%.6f", $1 / $2}')
        ${ffmpeg}/bin/ffmpeg $ffmpeg_verbose_flag -i "$sourcefile" \
            -f segment -segment_time "$seg_dur" -c copy \
            "''${basename_noext}_%03d.mp3"
    else
        # Validate MM:SS format
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
        ${ffmpeg}/bin/ffmpeg $ffmpeg_verbose_flag -i "$sourcefile" \
            -f segment -segment_time "$seg_dur" -c copy \
            "''${basename_noext}_%03d.mp3"
    fi
  ''
)
// {
  meta = {
    description = "Split an MP3 file into N equal segments or segments of a given length.";
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
