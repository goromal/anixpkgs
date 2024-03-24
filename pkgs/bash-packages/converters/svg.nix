{ writeArgparseScriptBin, callPackage, color-prints, strings, redirects
, inkscape, abcm2ps, scour }:
let
  name = "svg";
  extension = "svg";
  usage_str = ''
    usage: svg inputfile outputfile

    Create an svg file.

    Inputs:
        .svg
        .abc
        .pdf

    Options:
        --crop    | svg [x] abc [ ] pdf [x]
        --rmtext  | svg [x] abc [ ] pdf [x]
        --poppler | svg [x] abc [ ] pdf [x]
        --scour   | svg [x] abc [x] pdf [x]
        --rmwhite | svg [x] abc [x] pdf [x]
  '';
  optsWithVarsAndDefaults = [
    {
      var = "crop";
      isBool = true;
      default = "0";
      flags = "--crop";
    }
    {
      var = "scour";
      isBool = true;
      default = "0";
      flags = "--scour";
    }
    {
      var = "rmtext";
      isBool = true;
      default = "0";
      flags = "--rmtext";
    }
    {
      var = "rmwhite";
      isBool = true;
      default = "0";
      flags = "--rmwhite";
    }
    {
      var = "poppler";
      isBool = true;
      default = "0";
      flags = "--poppler";
    }
  ];
  scour_args =
    "--enable-viewboxing --enable-id-stripping --enable-comment-stripping --shorten-ids --indent=none";
  convOptCmds = [
    {
      extension = "svg|SVG";
      commands = ''
        ${color-prints}/bin/echo_yellow "SVG SELF-OPS NOT IMPLEMENTED YET"
      '';
    }
    {
      extension = "abc|ABC";
      commands = ''
        tmpdir=$(mktemp -d)
        ${abcm2ps}/bin/abc2ps "$infile" -v -O $tmpdir/step1.svg ${redirects.suppress_all}
        if [[ "$scour" == "1" ]]; then
            ${scour}/bin/scour -i $tmpdir/step1.svg -o $tmpdir/step2.svg ${scour_args} ${redirects.suppress_all}
        else
            mv $tmpdir/step1.svg $tmpdir/step2.svg
        fi
        if [[ "$rmwhite" == 1 ]]; then
            ${color-prints}/bin/echo_yellow "RMWHITE NOT IMPLEMENTED YET"
            mv $tmpdir/step2.svg "$outfile"
        else
            mv $tmpdir/step2.svg "$outfile"
        fi
        rm -rf $tmpdir
      '';
    }
    {
      extension = "pdf|PDF";
      commands = ''
        tmpdir=$(mktemp -d)
        inkscape_flags="--pdf-page=1 --export-dpi=300 --export-filename=$tmpdir/step1.svg"
        if [[ "$poppler" == "1" ]]; then
            inkscape_flags="$inkscape_flags --pdf-poppler"
        fi
        if [[ "$crop" == "1" ]]; then
            inkscape_flags="$inkscape_flags --export-area-drawing"
        fi
        ${inkscape}/bin/inkscape $inkscape_flags "$infile" ${redirects.suppress_all}
        if [[ "$rmtext" == "1" ]]; then
            ${color-prints}/bin/echo_yellow "RMTEXT NOT IMPLEMENTED YET"
            mv $tmpdir/step1.svg $tmpdir/step2.svg
        else
            mv $tmpdir/step1.svg $tmpdir/step2.svg
        fi
        if [[ "$rmwhite" == "1" ]]; then
            ${color-prints}/bin/echo_yellow "RMWHITE NOT IMPLEMENTED YET"
            mv $tmpdir/step2.svg $tmpdir/step3.svg
        else
            mv $tmpdir/step2.svg $tmpdir/step3.svg
        fi
        if [[ "$scour" == "1" ]]; then
            ${scour}/bin/scour -i $tmpdir/step3.svg -o "$outfile" ${scour_args} ${redirects.suppress_all}
        else
            mv $tmpdir/step3.svg "$outfile"
        fi
        rm -rf $tmpdir
      '';
    }
  ];
in callPackage ./mkConverter.nix {
  inherit writeArgparseScriptBin color-prints strings;
  inherit name extension usage_str optsWithVarsAndDefaults convOptCmds;
  description = "Generate and edit SVG files from a variety of source formats.";
}
