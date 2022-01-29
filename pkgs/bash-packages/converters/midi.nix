{ writeShellScriptBin
, callPackage
, color-prints
, strings
, redirects
}:
let
    name = "midi";
    extension = "midi";
    usage_str = ''
    usage: midi inputfile outputfile

    Create a MIDI file.

    Inputs:
        .midi
        .mp3
        .abc

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