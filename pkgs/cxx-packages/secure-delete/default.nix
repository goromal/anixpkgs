{ stdenv
, pkg-src
}:
let
    progName = "secure-delete";
in stdenv.mkDerivation {
    name = progName;
    version = "0.0.1";
    src = pkg-src;
    buildPhase = ''
        gcc src.c -o ${progName}
    '';
    installPhase = ''
        mkdir -p $out/bin
        cp ${progName} $out/bin
    '';
}