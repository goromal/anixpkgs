{ writeShellScriptBin
, callPackage
, color-prints
, strings
, redirects
}:
let
    name = "doku";
    extension = "doku";
    usage_str = ''
    usage: doku inputfile outputfile

    Create a DokuWiki text file.

    Inputs:
        .txt (DokuWiki format)
        .html

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