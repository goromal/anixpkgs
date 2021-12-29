{ stdenv 
, writeShellScriptBin
}:
let
    # https://en.wikipedia.org/wiki/ANSI_escape_code
    echo-color = colorname: colorcode:
        writeShellScriptBin "echo_${colorname}" ''
            echo -e "\033[1;${builtins.toString colorcode}m$@\033[0m"
        '';
    echo-green = echo-color "green" 32;
    echo-cyan = echo-color "cyan" 36;
    echo-red = echo-color "red" 31;
    echo-yellow = echo-color "yellow" 33;
in stdenv.mkDerivation {
    name = "color-prints";
    version = "1.0.0";
    unpackPhase = "true";
    installPhase = ''
        mkdir -p $out/bin
        cp ${echo-green}/bin/echo_green $out/bin
        cp ${echo-cyan}/bin/echo_cyan $out/bin
        cp ${echo-red}/bin/echo_red $out/bin
        cp ${echo-yellow}/bin/echo_yellow $out/bin
    '';
}
