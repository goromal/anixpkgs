{ writeShellScriptBin
, callPackage
, color-prints
, strings
, redirects
, ffmpeg
}:
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

    Options:
        -v | --verbose               Print verbose output from ffmpeg
        -q | --quality CHAR          - for low, = for medium, + for high bit rate quality
        -w | --width WIDTH           Constrain the video width (pixels)
        -l | --label "STR"           Add label to bottom left corner of video
        -f | --fontsize INT          Font size for added text
        -c | --crop INT:INT:INT:INT  Crop video (pre-labeling) W:H:X:Y
        -s | --start TIME            INITIAL time: [HH:]MM:SS[.0]
        -e | --end TIME              FINAL time: [HH:]MM:SS[.0]
    '';
    
    optsWithVarsAndDefaults = [
        { var = "verbose";  isBool = true;  default = "0";  flags = "-v|--verbose"; }
        { var = "quality";  isBool = false; default = "";   flags = "-q|--quality"; }
        { var = "width";    isBool = false; default = "";   flags = "-w|--width"; }
        { var = "label";    isBool = false; default = "";   flags = "-l|--label"; }
        { var = "fontsize"; isBool = false; default = "24"; flags = "-f|--fontsize"; }
        { var = "crop";     isBool = false; default = "";   flags = "-c|--crop"; }
        { var = "start";    isBool = false; default = "";   flags = "-s|--start"; }
        { var = "end";      isBool = false; default = "";   flags = "-e|--end"; }
    ];

    printErr = "${color-prints}/bin/echo_red";

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
        { extension = "mp4|MP4|gif|GIF|mpeg|MPEG|mkv|MKV|mov|MOV|avi|AVI|webm|WEBM"; commands = ''
        ffmpeg_args=("-vcodec" "libx264")
        ${qualityRule}
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
        ''; }
    ];
in callPackage ./mkConverter.nix {
    inherit writeShellScriptBin callPackage color-prints strings;
    inherit name extension usage_str optsWithVarsAndDefaults convOptCmds;
}