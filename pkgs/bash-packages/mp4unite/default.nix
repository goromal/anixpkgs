{ writeShellScriptBin, callPackage, color-prints, strings, redirects, ffmpeg }:
let
  pkgname = "mp4unite";
  argparse = callPackage ../bash-utils/argparse.nix {
    usage_str = ''
      usage: ${pkgname} [options] <MP4-sourcefile-1>..<MP4-sourcefile-n> <MP4-destfile>

      Combine MP4 source files into a single destination MP4 file.

      Options:
      -h | --help     Print out the help documentation.
      -v | --verbose  Print verbose output from ffmpeg
    '';
    optsWithVarsAndDefaults = [{
      var = "verbose";
      isBool = true;
      default = "0";
      flags = "-v|--verbose";
    }];
  };
  printErr = "${color-prints}/bin/echo_red";
in (writeShellScriptBin pkgname ''
  ${argparse}
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
      if [[ "$fileargext" != "mp4" && "$fileargext" != "MP4" ]]; then
          ${printErr} "File argument does not have an mp4 extension: $filearg"
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
  echo "# video concatenation list:" > "$ctfilename"
  i=0
  for sourcefile in "''${sourcefiles[@]}"; do
      (( i++ ))
      cp "$sourcefile" "$tmpdir/__cnct__$i.mp4"
      echo "file $tmpdir/__cnct__$i.mp4" >> "$ctfilename"
  done
  if [[ "$verbose" == "0" ]]; then
      ${ffmpeg}/bin/ffmpeg -f concat -safe 0 -i "$ctfilename" -c copy "$destfile" ${redirects.suppress_all}
  else
      echo "ffmpeg -f concat -safe 0 -i $ctfilename -c copy $destfile"
      ${ffmpeg}/bin/ffmpeg -f concat -safe 0 -i "$ctfilename" -c copy "$destfile"
  fi

  rm -rf "$tmpdir"
'') // {
  meta = {
    description = "Unite mp4 files, much like with the `pdfunite` tool.";
    longDescription = ''
      ```
      usage: mp4unite [options] <MP4-sourcefile-1>..<MP4-sourcefile-n> <MP4-destfile>

      Combine MP4 source files into a single destination MP4 file.

      Options:
      -h | --help     Print out the help documentation.
      -v | --verbose  Print verbose output from ffmpeg
      ```
    '';
  };
}
