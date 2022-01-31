{ writeShellScriptBin
, callPackage
, color-prints
, strings
, redirects
}:
let
    name = "png";
    extension = "png";
    usage_str = ''
    usage: png inputfile outputfile

    Create a png file.

    Inputs:
        .png
        .gif
        .svg
        .jpeg
        .heic
        .tiff

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