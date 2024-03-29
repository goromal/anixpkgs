{ writeArgparseScriptBin, callPackage, color-prints, strings, redirects }:
let
  name = "md";
  extension = "md";
  usage_str = ''
    usage: md inputfile outputfile

    Create a Markdown file.

    Inputs:
        .md
        .doku
        .pdf

    Options:
        --TODO
  '';
  optsWithVarsAndDefaults = [

  ];
  convOptCmds = [{
    extension = "*";
    commands = ''
      echo_yellow "NOT IMPLEMENTED YET"
    '';
  }];
in callPackage ./mkConverter.nix {
  inherit writeArgparseScriptBin color-prints strings;
  inherit name extension usage_str optsWithVarsAndDefaults convOptCmds;
  description =
    "Generate Markdown files from similar formats (*not finished yet!*).";
}
