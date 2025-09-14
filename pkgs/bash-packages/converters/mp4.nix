{ writeArgparseScriptBin, callPackage, color-prints, strings, redirects, ffmpeg
, openssl }:
let
  name = "mp4";
  extension = "mp4";
  usage_str = ''
    usage: mp4 inputfile outputfile

    Create a mp4 file.

    Inputs:
        .mp4
        .gif
        .mpeg
        .mkv
        .mov
        .avi
        .webm
        .random (e.g., seed-width-height-frames.random)

    Options:
        -v | --verbose               Print verbose output from ffmpeg
        -m | --mute                  Remove audio
        -q | --quality CHAR          - for low, = for medium, + for high bit rate quality
        -w | --width WIDTH           Constrain the video width (pixels)
        -l | --label "STR"           Add label to bottom left corner of video
        -f | --fontsize INT          Font size for added text
        -c | --crop INT:INT:INT:INT  Crop video (pre-labeling) W:H:X:Y
        -s | --start TIME            INITIAL time: [HH:]MM:SS[.0]
        -e | --end TIME              FINAL time: [HH:]MM:SS[.0]
  '';

  optsWithVarsAndDefaults = [
    {
      var = "verbose";
      isBool = true;
      default = "0";
      flags = "-v|--verbose";
    }
    {
      var = "mute";
      isBool = true;
      default = "0";
      flags = "-m|--mute";
    }
    {
      var = "quality";
      isBool = false;
      default = "";
      flags = "-q|--quality";
    }
    {
      var = "width";
      isBool = false;
      default = "";
      flags = "-w|--width";
    }
    {
      var = "label";
      isBool = false;
      default = "";
      flags = "-l|--label";
    }
    {
      var = "fontsize";
      isBool = false;
      default = "24";
      flags = "-f|--fontsize";
    }
    {
      var = "crop";
      isBool = false;
      default = "";
      flags = "-c|--crop";
    }
    {
      var = "start";
      isBool = false;
      default = "";
      flags = "-s|--start";
    }
    {
      var = "end";
      isBool = false;
      default = "";
      flags = "-e|--end";
    }
  ];

  printWarn = "${color-prints}/bin/echo_yellow";
  printErr = ">&2 ${color-prints}/bin/echo_red";

  qualityRule = ''
    if [[ ! -z "$quality" ]]; then
        if [[ "$quality" == "-" ]]; then
            ffmpeg_args+=( "-crf" "30" )
        elif [[ "$quality" == "=" ]]; then
            ffmpeg_args+=( "-crf" "27" )
        elif [[ "$quality" == "+" ]]; then
            ffmpeg_args+=( "-crf" "24" )
        else
            ${printErr} "Unrecognized quality flag: $quality"
            exit 1
        fi
    fi
  '';

  audioRule = ''
    if [[ "$mute" == "1" ]]; then
        ffmpeg_args+=( "-an" )
    fi
  '';

  widthRule = ''
    if [[ ! -z "$width" ]]; then
        ffmpeg_args+=( "-vf" "scale=$width:-1" )
    fi
  '';

  fontfile = ./res/fonts/roboto.ttf;
  labelRule = ''
    if [[ ! -z "$label" ]]; then
        ffmpeg_args+=( "-vf" "drawtext=fontfile=${fontfile}:text=$label:fontcolor=white:fontsize=$fontsize:box=1:boxcolor=black@0.75:boxborderw=10:x=10:y=h-text_h-10" )
    fi
  '';

  cropRule = ''
    if [[ ! -z "$crop" ]]; then
        ffmpeg_args+=( "-filter:v" "crop=$crop" )
    fi
  '';

  startRule = ''
    if [[ ! -z "$start" ]]; then
        ffmpeg_args+=( "-ss" "$start" )
    fi
  '';

  endRule = ''
    if [[ ! -z "$end" ]]; then
        ffmpeg_args+=( "-to" "$end" )
    fi
  '';

  convOptCmds = [
    {
      extension = "mp4|MP4|gif|GIF|mpeg|MPEG|mkv|MKV|mov|MOV|avi|AVI|webm|WEBM";
      commands = ''
        ffmpeg_args=("-y" "-vcodec" "libx264")
        ${qualityRule}
        ${audioRule}
        ${widthRule}
        ${labelRule}
        ${cropRule}
        ${startRule}
        ${endRule}
        if [[ "$verbose" == "0" ]]; then
            ${ffmpeg}/bin/ffmpeg -i "$infile" "''${ffmpeg_args[@]}" "$outfile" ${redirects.suppress_all}
        else
            echo "ffmpeg -i $infile ''${ffmpeg_args[@]} $outfile"
            ${ffmpeg}/bin/ffmpeg -i "$infile" "''${ffmpeg_args[@]}" "$outfile"
        fi
      '';
    }
    {
      extension = "random|RANDOM|rand|RAND";
      commands = ''
        if [[ ! "$infile" =~ ^([^-]+)-([0-9]+)-([0-9]+)-([0-9]+)\.random$ ]]; then
          ${printErr} "Random inputfile must be of form seed-width-height-frames.random"
          exit 1
        fi
        tmpdir=$(mktemp -d)
        seed="''${BASH_REMATCH[1]}"
        width="''${BASH_REMATCH[2]}"
        height="''${BASH_REMATCH[3]}"
        frames="''${BASH_REMATCH[4]}"
        ${printWarn} "Generating a random ''${frames}-frame ''${width}x''${height} MP4 with seed $seed -> ''${outfile}..."
        key=$(printf "%s" "$seed" | sha256sum | awk '{print $1}')
        nbytes=$((width * height * 3 * frames))
        dd if=/dev/zero bs=$nbytes count=1 2>/dev/null \
          | ${openssl}/bin/openssl enc -aes-256-ctr -K "$key" -iv 0 \
          > $tmpdir/rand.rgb
        ${ffmpeg}/bin/ffmpeg -y \
          -f rawvideo -pix_fmt rgb24 -s:v ''${width}x''${height} -r 30 -i $tmpdir/rand.rgb \
          -frames:v "$frames" \
          -an \
          -vcodec libx264 \
          -preset veryfast \
          -crf 0 \
          -movflags +faststart \
          -fflags +bitexact \
          -flags:v +bitexact \
          -map_metadata -1 \
          -metadata creation_time=0 \
          "$outfile"
        rm -r $tmpdir
      '';
    }
  ];
in callPackage ./mkConverter.nix {
  inherit writeArgparseScriptBin color-prints strings;
  inherit name extension usage_str optsWithVarsAndDefaults convOptCmds;
  description = "Generate and edit MP4 video files using `ffmpeg`.";
}
