{
  writeArgparseScriptBin,
  callPackage,
  color-prints,
  strings,
  redirects,
  inkscape,
}:
let
  name = "pdf";
  extension = "pdf";
  usage_str = ''
    usage: pdf inputfile outputfile

    Create a pdf file.

    Inputs:
        .pdf
        .md
        .doku
        .epub
        .svg

    Options:
        --TODO
  '';
  optsWithVarsAndDefaults = [

  ];
  convOptCmds = [
    {
      extension = "svg|SVG";
      commands = ''
        ${inkscape}/bin/inkscape --export-area-drawing --without-gui --export-pdf="$outfile" "$infile" ${redirects.suppress_all}
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
  description = "Create and edit PDF files from similar formats (*under construction*).";
}
