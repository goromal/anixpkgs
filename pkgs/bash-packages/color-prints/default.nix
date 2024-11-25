{ stdenv, writeShellScriptBin }:
let
  # https://en.wikipedia.org/wiki/ANSI_escape_code
  echo-color = colorname: colorcode:
    writeShellScriptBin "echo_${colorname}" ''
      FLAGS='-e'
      POSITIONAL=()
      while [[ $# -gt 0 ]]
      do
      key="$1"
      case $key in
          -n)
          FLAGS="''${FLAGS} -n"
          shift
          ;;
          -e)
          FLAGS="''${FLAGS}"
          shift
          ;;
          -en|-ne)
          FLAGS="''${FLAGS} -n"
          shift
          ;;
          *)    # unknown option
          POSITIONAL+=("$1") # save it in an array for later
          shift # past argument
          ;;
      esac
      done
      set -- "''${POSITIONAL[@]}" # restore positional parameters
      echo $FLAGS "\033[1;${builtins.toString colorcode}m$@\033[0m"
    '';
  echo-black = echo-color "black" 30;
  echo-red = echo-color "red" 31;
  echo-green = echo-color "green" 32;
  echo-yellow = echo-color "yellow" 33;
  echo-blue = echo-color "blue" 34;
  echo-magenta = echo-color "magenta" 35;
  echo-cyan = echo-color "cyan" 36;
  echo-white = echo-color "white" 37;
in stdenv.mkDerivation {
  name = "color-prints";
  version = "1.0.0";
  unpackPhase = "true";
  installPhase = ''
    mkdir -p                            $out/bin
    cp ${echo-black}/bin/echo_black     $out/bin
    cp ${echo-red}/bin/echo_red         $out/bin
    cp ${echo-green}/bin/echo_green     $out/bin
    cp ${echo-yellow}/bin/echo_yellow   $out/bin
    cp ${echo-blue}/bin/echo_blue       $out/bin
    cp ${echo-magenta}/bin/echo_magenta $out/bin
    cp ${echo-cyan}/bin/echo_cyan       $out/bin
    cp ${echo-white}/bin/echo_white     $out/bin
  '';
  meta = {
    description = "Color-formatted wrapped `echo` commands.";
    longDescription = ''
      ANSI color codes referenced from [Wikipedia](https://en.wikipedia.org/wiki/ANSI_escape_code).

      - `echo_black`
      - `echo_red`
      - `echo_green`
      - `echo_yellow`
      - `echo_blue`
      - `echo_magenta`
      - `echo_cyan`
      - `echo_white`
    '';
  };
}
