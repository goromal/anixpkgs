{ writeShellScript
, coreutils
, gcc
, bash
}:
let
    progName = "secure-delete";
    builderScript = writeShellScript "builder.sh" ''
        export PATH="$coreutils/bin:$gcc/bin"
        mkdir $out
        gcc -o $out/${progName} $src/src.c
    '';
in derivation {
    name = progName;
    version = "0.0.1";
    builder = "${bash}/bin/bash";
    args = [ builderScript ];
    inherit gcc coreutils;
    src = builtins.fetchGit (import ./src.nix);
    system = builtins.currentSystem;
}
