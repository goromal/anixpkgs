{ writeShellScriptBin
, callPackage
, color-prints
, strings
, redirects
, abcmidi
}:
let
    name = "abc";
    extension = "abc";
    usage_str = ''
    usage: abc inputfile outputfile

    Create an abc file.

    Inputs:
        .smf
        .midi
    '';
    optsWithVarsAndDefaults = [ ];
    convOptCmds = [
        { extension = "midi|MIDI"; commands = ''
            ${abcmidi}/bin/midi2abc "$infile" -o "$outfile" ${redirects.suppress_stdout}
        ''; }
        { extension = "smf|SMF"; commands = ''
            ${color-prints}/bin/echo_yellow "NOT YET IMPLEMENTED"
        ''; }
    ];
in callPackage ./mkConverter.nix {
  inherit writeShellScriptBin callPackage color-prints strings;
  inherit name extension usage_str optsWithVarsAndDefaults convOptCmds;
}
