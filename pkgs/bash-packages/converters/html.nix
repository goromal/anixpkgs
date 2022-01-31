{ writeShellScriptBin
, callPackage
, color-prints
, strings
, redirects
}:
let
    name = "html";
    extension = "html";
    usage_str = ''
    usage: html inputfile outputfile

    Create an HTML file.

    Inputs:
        .html
        .txt (DokuWiki format)
        .md

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