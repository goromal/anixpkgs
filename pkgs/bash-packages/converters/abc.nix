{ writeArgparseScriptBin, callPackage, color-prints, strings, redirects, python3
, abcmidi }:
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
  smf2abc_py = ./res/smf2abc.py;
  convOptCmds = [
    {
      extension = "midi|MIDI";
      commands = ''
        ${abcmidi}/bin/midi2abc "$infile" -o "$outfile" ${redirects.suppress_stdout}
      '';
    }
    {
      extension = "smf|SMF";
      commands = ''
        convres=$(${python3}/bin/python3 ${smf2abc_py} "$infile" "$outfile")
        [[ -z "$convres" ]] || ${color-prints}/bin/echo_red "$convres"
      '';
    }
  ];
in callPackage ./mkConverter.nix {
  inherit writeArgparseScriptBin color-prints strings;
  inherit name extension usage_str optsWithVarsAndDefaults convOptCmds;
  description =
    "Generate [abc music files](https://abcnotation.com/) from similar formats.";
}
