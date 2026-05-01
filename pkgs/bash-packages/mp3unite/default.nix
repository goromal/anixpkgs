{
  writeArgparseScriptBin,
  color-prints,
  strings,
  redirects,
  ffmpeg,
}:
let
  pkgname = "mp3unite";
  printErr = "${color-prints}/bin/echo_red";
in
(writeArgparseScriptBin pkgname
  ''
    usage: ${pkgname} [options] <MP3-sourcefile-1>..<MP3-sourcefile-n> <MP3-destfile>

    Combine MP3 source files into a single destination MP3 file.

    Options:
    -h | --help     Print out the help documentation.
    -v | --verbose  Print verbose output from ffmpeg
  ''
  [
    {
      var = "verbose";
      isBool = true;
      default = "0";
      flags = "-v|--verbose";
    }
  ]
  ''
    if [ "$#" -lt "3" ]; then
        ${printErr} "Insufficient arguments provided"
        exit 1
    fi
    i=0
    sourcefiles=()
    destfile=""
    for filearg in "$@"; do
        (( i++ ))
        fileargext=`${strings.getExtension} "$filearg"`
        if [[ "$fileargext" != "mp3" && "$fileargext" != "MP3" ]]; then
            ${printErr} "File argument does not have an mp3 extension: $filearg"
            exit 1
        fi
        if [ "$i" -lt "$#" ]; then
            if [[ ! -f "$filearg" ]]; then
                ${printErr} "Source file does not exist: $filearg"
                exit 1
            fi
            sourcefiles+=( "$filearg" )
        else
            if [[ -f "$filearg" ]]; then
                while true; do
                    read -p "Destination file exists ($filearg); remove? [yn] " yn
                    case $yn in
                        [Yy]* ) rm "$filearg"; break;;
                        [Nn]* ) echo "Aborting."; exit;;
                        * ) ${printErr} "Please respond y or n";;
                    esac
                done
            fi
            destfile="$filearg"
        fi
    done

    tmpdir=$(mktemp -d)

    ctfilename="$tmpdir/__cnct__.ct"
    echo "# audio concatenation list:" > "$ctfilename"
    i=0
    for sourcefile in "''${sourcefiles[@]}"; do
        (( i++ ))
        cp "$sourcefile" "$tmpdir/__cnct__$i.mp3"
        echo "file $tmpdir/__cnct__$i.mp3" >> "$ctfilename"
    done
    if [[ "$verbose" == "0" ]]; then
        ${ffmpeg}/bin/ffmpeg -f concat -safe 0 -i "$ctfilename" -c copy "$destfile" ${redirects.suppress_all}
    else
        echo "ffmpeg -f concat -safe 0 -i $ctfilename -c copy $destfile"
        ${ffmpeg}/bin/ffmpeg -f concat -safe 0 -i "$ctfilename" -c copy "$destfile"
    fi

    rm -rf "$tmpdir"
  ''
)
// {
  meta = {
    description = "Unite mp3 files, much like with the `pdfunite` tool.";
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
