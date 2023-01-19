{ writeShellScript
, coreutils
, gcc
, bash
, pkg-src
}:
let
    progName = "secure-delete";
    builderScript = writeShellScript "builder.sh" ''
        export PATH="$coreutils/bin:$gcc/bin"
        mkdir -p $out/bin
        gcc -o $out/bin/${progName} $src/src.c
    '';
in derivation {
    name = progName;
    version = "0.0.1";
    builder = "${bash}/bin/bash";
    args = [ builderScript ];
    inherit gcc coreutils;
    src = pkg-src;
    system = builtins.currentSystem;
}
