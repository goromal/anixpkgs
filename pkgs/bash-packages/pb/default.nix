{ writeArgparseScriptBin, color-prints }:
let
  pkgname = "pb";
  usage = ''
    usage: ${pkgname} [options] iternum itertot

    Prints a progress bar.

    Options:
    -h | --help     Print out the help documentation.
    -b | --barsize  Dictate the total progress bar length in chars (Default: 20).
    -c | --color    One of [black|red|green|yellow|blue|magenta|cyan|white].

    Arguments:
    iternum: current iteration number
    itertot: number of total iterations
  '';
  example = ''
    N=0
    T=20
    while [ \$N -le \$T ]; do
        pb \$N \$T
        N=\$[\$N+1]
        sleep 1
    done
    echo
  '';
  usage_str = ''
    ${usage}

    Example Usage:

    ${example}
  '';
  printErr = "${color-prints}/bin/echo_red";
in (writeArgparseScriptBin pkgname usage_str [
  {
    var = "barsize";
    isBool = false;
    default = "20";
    flags = "-b|--barsize";
  }
  {
    var = "color";
    isBool = false;
    default = "";
    flags = "-c|--color";
  }
] ''
  if [[ -z "$1" ]]; then
      ${printErr} "No iternum provided."
      exit 1
  fi
  if [[ -z "$2" ]]; then
      ${printErr} "No itertot provided."
      exit 1
  fi
  ITERNUM=$1
  ITERTOT=$2
  BARSIZE=$barsize
  ECHOCOM="echo"
  if [[ ! -z "$color" ]]; then
      if [[ ! ( "$color" == "black" || "$color" == "red" || "$color" == "green" \
             || "$color" == "yellow" || "$color" == "blue" || "$color" == "magenta" \
             || "$color" == "cyan" || "$color" == "white" ) ]]; then
          ${printErr} "Invalid color provided."
          exit 1
      fi
      ECHOCOM="${color-prints}/bin/echo_$color"
  fi

  PADCHAR='\u2588' # if $BASH_VERSION >= 4.2
  # https://en.wikipedia.org/wiki/Box-drawing_character

  echoCharWithLength() {
      CHAR=$1
      LENGTH=$2
      N=0
      while [ $N -lt $LENGTH ]; do
          $ECHOCOM -en "$CHAR"
          N=$[$N+1]
      done
  }

  PERCENTAGE=$((100 * $ITERNUM / $ITERTOT))
  BARNUM=$(($BARSIZE * $ITERNUM / $ITERTOT))
  SPCNUM=$(($BARSIZE - $BARNUM))

  $ECHOCOM -n "["
  echoCharWithLength $PADCHAR $BARNUM
  echoCharWithLength ' ' $SPCNUM
  ENDSTR1="] "
  $ECHOCOM -n "$ENDSTR1"
  echo -ne "(''${PERCENTAGE}%)\r"
'') // {
  meta = {
    description = "Print out a progress bar.";
    longDescription = ''
      Example usage:

      ```
      ${example}
      ```
    '';
    autoGenUsageCmd = "--help";
  };
}
