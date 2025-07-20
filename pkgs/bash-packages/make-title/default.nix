{ writeArgparseScriptBin, color-prints }:
let
  pkgname = "make-title";
  printErr = "${color-prints}/bin/echo_red";
in (writeArgparseScriptBin pkgname ''
  usage: ${pkgname} [options] title

  Prints out a decorated title.

  Options:
  -h | --help     Print out the help documentation.
  -c | --color    One of [black|red|green|yellow|blue|magenta|cyan|white].

  Arguments:
  title           word or phrase making up the title
'' [{
  var = "color";
  isBool = false;
  default = "";
  flags = "-c|--color";
}] ''
  if [[ -z "$1" ]]; then
      ${printErr} "No title provided."
      exit 1
  fi
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

  WSPADDING="        "
  PADCHAR="="

  echoPaddingWithLengthOf() {
  PC=$1
  shift
  STR="$@"
  SPACELESS=(''${STR// /-})
  STRLIST=`echo $SPACELESS | fold -w1`
  for i in $STRLIST; do
      $ECHOCOM -en "$PC"
  done
  }

  TITLEBUFFER1="....."
  TITLEBUFFER2=".."
  echoPaddingWithLengthOf $PADCHAR $TITLEBUFFER1
  echoPaddingWithLengthOf $PADCHAR "$@"
  echoPaddingWithLengthOf $PADCHAR $TITLEBUFFER1
  echoPaddingWithLengthOf $PADCHAR $TITLEBUFFER2
  echo
  echoPaddingWithLengthOf $PADCHAR $TITLEBUFFER1
  echo -n " $@ "
  echoPaddingWithLengthOf $PADCHAR $TITLEBUFFER1
  echo
  echoPaddingWithLengthOf $PADCHAR $TITLEBUFFER1
  echoPaddingWithLengthOf $PADCHAR "$@"
  echoPaddingWithLengthOf $PADCHAR $TITLEBUFFER1
  echoPaddingWithLengthOf $PADCHAR $TITLEBUFFER2
  echo
'') // {
  meta = {
    description = "Print decorated titles.";
    longDescription = ''
      Example:

      ```
      $ make-title "Hello, World"
      ========================
      ===== Hello, World =====
      ========================
      ```
    '';
    autoGenUsageCmd = "--help";
  };
}
