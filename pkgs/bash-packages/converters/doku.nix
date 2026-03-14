{
  writeArgparseScriptBin,
  callPackage,
  color-prints,
  strings,
  redirects,
}:
let
  name = "doku";
  extension = "doku";
  usage_str = ''
    usage: doku inputfile outputfile

    Create a DokuWiki page.

    Inputs:
        .txt (DokuWiki format)
        .md

    Options:
        --TODO
  '';
  optsWithVarsAndDefaults = [

  ];
  convOptCmds = [
    {
      extension = "*";
      commands = ''
        echo_yellow "NOT IMPLEMENTED YET"
      '';
    }
  ];
in
callPackage ./mkConverter.nix {
  inherit writeArgparseScriptBin color-prints strings;
  inherit
    name
    extension
    usage_str
    optsWithVarsAndDefaults
    convOptCmds
    ;
  description = "Generate a DokuWiki text page from similar formats (*not finished yet!*).";
}
