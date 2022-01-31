{ writeShellScriptBin
, callPackage
, color-prints
, strings
, redirects
}:
let
    name = "gif";
    extension = "gif";
    usage_str = ''
    usage: gif inputfile outputfile

    Create a GIF file.

    Inputs:
        .gif
        .mp4
        .png

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