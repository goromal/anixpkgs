{ writeShellScriptBin
, callPackage
, color-prints
, strings
, redirects
}:
let
    name = "zipper";
    extension = "zip";
    usage_str = ''
    usage: zipper inputfile outputfile

    Create a zipped archive.

    Inputs:
        .anything

    Options:
        --TODO
    '';
    optsWithVarsAndDefaults = [
        
    ];
    convOptCmds = [
        { extension = "*"; commands = ''
        echo_yellow "NOT IMPLEMENTED YET"
        ''; }
    ];
in callPackage ./mkConverter.nix {
    inherit writeShellScriptBin callPackage color-prints strings;
    inherit name extension usage_str optsWithVarsAndDefaults convOptCmds;
    description = "Dead-simple compression utility (*not finished*).";
}