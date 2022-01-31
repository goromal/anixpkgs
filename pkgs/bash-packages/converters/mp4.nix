{ writeShellScriptBin
, callPackage
, color-prints
, strings
, redirects
}:
let
    name = "mp4";
    extension = "mp4";
    usage_str = ''
    usage: mp4 inputfile outputfile

    Create a mp4 file.

    Inputs:
        .mp4
        .gif
        .mpeg
        .mkv
        .mov
        .avi

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