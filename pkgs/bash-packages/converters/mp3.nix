{ writeShellScriptBin
, callPackage
, color-prints
, strings
, redirects
}:
let
    name = "mp3";
    extension = "mp3";
    usage_str = ''
    usage: mp3 inputfile outputfile

    Create a mp3 file.

    Inputs:
        .mp3
        .mp4
        .wav
        .midi

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