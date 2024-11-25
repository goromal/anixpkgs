{ writeArgparseScriptBin, callPackage, color-prints, strings, redirects }:
let
  name = "epub";
  extension = "epub";
  usage_str = ''
    usage: epub inputfile outputfile

    Create an EPUB file.

    Inputs:
        .epub
        .md

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
    "Generate EPUB files from similar formats (*not finished yet!*).";
}
