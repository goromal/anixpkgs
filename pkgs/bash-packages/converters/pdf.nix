{ writeShellScriptBin
, callPackage
, color-prints
, strings
, redirects
}:
let
    name = "pdf";
    extension = "pdf";
    usage_str = ''
    usage: pdf inputfile outputfile

    Create a pdf file.

    Inputs:
        .pdf
        .md
        .epub
        .svg

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
}