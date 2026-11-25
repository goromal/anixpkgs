{
  writeArgparseScriptBin,
  callPackage,
  color-prints,
  strings,
  redirects,
  ffmpeg,
  openssl,
  writeShellApplication,
  coreutils,
  gawk,
  gnugrep,
  gnused,
  openssh,
  writers,
  python3Packages,
}:
let
  name = "mp4";
  extension = "mp4";
  usage_str = ''
    usage: mp4 [opts] inputfile outputfile
           mp4 [opts] vacuum directory

    Create a mp4 file.

    With the "vacuum" sub-command, dispatch an orchestrator job for every file
    with a supported input extension -- excluding .mp4 itself -- in the given
    directory, preserving each filename (only the extension changes). Every
    option above applies to each dispatched conversion, and each source file is
    removed only once its conversion has succeeded.

    With --upscale, the output is a restored, upscaled copy (1080p tall by
    default) and the source is always kept. Vacuum writes NAME_upscaled.mp4
    next to each source, skips sources whose _upscaled output already exists
    (so an interrupted sweep resumes), and runs model jobs one at a time.

    Inputs:
        .mp4
        .gif
        .mpeg
        .mkv
        .mov
        .avi
        .webm
        .flv
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
        -u | --upscale MODE          Restore + upscale old video. MODE:
                                       classic  ffmpeg only: auto border crop,
                                                chroma realignment, smoothed
                                                white balance, denoise, deblock,
                                                aspect fix, Lanczos upscale,
                                                sharpen
                                       model    same front end + Real-ESRGAN on
                                                a Vulkan GPU (video2x)
             --stabilize             (upscale) Two-pass camera-shake removal
             --keep-color            (upscale) Skip the automatic white balance
             --model NAME            (upscale model) fast (default) or quality,
                                     or a video2x realesrgan model name
             --gpu INDEX             (upscale model) ncnn GPU index (default:
                                     first discrete GPU)
             --host HOST             (upscale model) Run the model pipeline on
                                     HOST over SSH (e.g. atorgesen-dell.local)
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
    {
      var = "upscale";
      isBool = false;
      default = "";
      flags = "-u|--upscale";
    }
    {
      var = "stabilize";
      isBool = true;
      default = "0";
      flags = "--stabilize";
    }
    {
      var = "keep_color";
      isBool = true;
      default = "0";
      flags = "--keep-color";
    }
    {
      var = "model";
      isBool = false;
      default = "";
      flags = "--model";
    }
    {
      var = "gpu";
      isBool = false;
      default = "";
      flags = "--gpu";
    }
    {
      var = "host";
      isBool = false;
      default = "";
      flags = "--host";
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

  analyzer = writers.writePython3Bin "mp4-upscale-analyze" {
    libraries = [ python3Packages.numpy ];
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./res/mp4-upscale-analyze.py);

  upscaler = writeShellApplication {
    name = "mp4-upscale";
    runtimeInputs = [
      analyzer
      ffmpeg
      coreutils
      gawk
      gnugrep
      gnused
      openssh
    ];
    text = ''
      MP4_UPSCALE_FONT=${fontfile}
    ''
    + builtins.readFile ./res/mp4-upscale.sh;
  };

  # Upscaling replaces the plain conversion entirely, so every option above is
  # forwarded to the upscaler rather than to ffmpeg.
  upscaleRule = ''
    if [[ -z "$upscale" ]]; then
        for opt in stabilize:0 keep_color:0 model: gpu: host:; do
            v="''${opt%%:*}"; d="''${opt#*:}"
            if [[ "''${!v}" != "$d" ]]; then
                ${printErr} "--''${v//_/-} only applies with --upscale."
                exit 1
            fi
        done
    else
        if [[ "$upscale" != "model" && ( -n "$model" || -n "$gpu" || -n "$host" ) ]]; then
            ${printErr} "--model, --gpu and --host only apply with --upscale model."
            exit 1
        fi
        up_args=( --fontsize "$fontsize" )
        [[ "$verbose" == "1" ]] && up_args+=( --verbose )
        [[ "$mute" == "1" ]] && up_args+=( --mute )
        [[ "$stabilize" == "1" ]] && up_args+=( --stabilize )
        [[ "$keep_color" == "1" ]] && up_args+=( --keep-color )
        [[ -n "$quality" ]] && up_args+=( --quality "$quality" )
        [[ -n "$width" ]] && up_args+=( --width "$width" )
        [[ -n "$crop" ]] && up_args+=( --crop "$crop" )
        [[ -n "$start" ]] && up_args+=( --start "$start" )
        [[ -n "$end" ]] && up_args+=( --end "$end" )
        [[ -n "$label" ]] && up_args+=( --label "$label" )
        [[ -n "$model" ]] && up_args+=( --model "$model" )
        [[ -n "$gpu" ]] && up_args+=( --gpu "$gpu" )
        [[ -n "$host" ]] && up_args+=( --host "$host" )
        ${upscaler}/bin/mp4-upscale "''${up_args[@]}" "$upscale" "$infile" "$outfile" || exit 1
    fi
  '';

  # Vacuum with --upscale never replaces or deletes anything: each source gets
  # a NAME_upscaled.mp4 sibling, already-produced outputs are skipped so a long
  # sweep can be re-run to resume, and model jobs are chained so only one uses
  # the GPU at a time.
  vacuumFileHook = ''
    if [[ ! -z "$upscale" ]]; then
        keep_source=1
        case "$f" in
        *_upscaled.mp4|*_upscaled.MP4) skip_file=1 ;;
        esac
        outfile="''${f%.*}_upscaled.mp4"
        if [[ -e "$outfile" ]]; then
            skip_file=1
        fi
        if [[ "$upscale" == "model" ]]; then
            serialize=1
        fi
    fi
  '';
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
      extension = "mp4|MP4|gif|GIF|mpeg|MPEG|mkv|MKV|mov|MOV|avi|AVI|webm|WEBM|flv|FLV";
      commands = ''
        ${upscaleRule}
        if [[ -z "$upscale" ]]; then
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
in
callPackage ./mkConverter.nix {
  inherit writeArgparseScriptBin color-prints strings;
  inherit
    name
    extension
    usage_str
    optsWithVarsAndDefaults
    convOptCmds
    vacuumFileHook
    ;
  description = "Generate and edit MP4 video files using `ffmpeg`.";
}
