{ writeArgparseScriptBin, callPackage, color-prints, strings, redirects
, imagemagick, openssl, libheif, exiftool }:
let
  name = "png";
  extension = "png";
  usage_str = ''
    usage: png [opts] inputfile outputfile

    Create a png file.

    Inputs:
        .png
        .gif
        .svg
        .jpeg
        .heic
        .tiff
        .random  (e.g., seed-width-height.random)

    Options:
        -r|--resize [e.g., 50%]  Resize the image.
        -s|--scrub               Scrub image metadata.
  '';
  optsWithVarsAndDefaults = [
    {
      var = "resize";
      isBool = false;
      default = "";
      flags = "-r|--resize";
    }
    {
      var = "scrub";
      isBool = true;
      default = "0";
      flags = "-s|--scrub";
    }
  ];
  printWarn = "${color-prints}/bin/echo_yellow";
  printErr = "${color-prints}/bin/echo_red";
  apply_resize = tmpdir_var: infile_var: outfile_varname: ''
    ${outfile_varname}="${tmpdir_var}/__postresize.png"
    ${imagemagick}/bin/convert -resize $resize ${infile_var} "''${${outfile_varname}}" ${redirects.suppress_all}
  '';
  apply_scrub = tmpdir_var: infile_var: outfile_varname: ''
    ${outfile_varname}="${tmpdir_var}/__postscrub.png"
    ${exiftool}/bin/exiftool -all= ${infile_var} -o "''${${outfile_varname}}" ${redirects.suppress_all}
  '';
  convOptCmds = [
    {
      extension = "png|PNG|jpeg|JPEG|jpg|JPG|tiff|TIFF";
      commands = ''
        tmpdir=$(mktemp -d)
        _stp1="$tmpdir/_stp1.png"
        ${imagemagick}/bin/convert "$infile" "$_stp1" ${redirects.suppress_all}
        if [[ ! -z "$resize" ]]; then
            ${apply_resize "$tmpdir" "$_stp1" "_stp2"}
        else
            _stp2="$_stp1"
        fi
        if [[ "$scrub" == "1" ]]; then
            ${apply_scrub "$tmpdir" "$_stp2" "_stp3"}
        else
            _stp3="$_stp2"
        fi
        mv "$_stp3" "$outfile"
        rm -rf $tmpdir
      '';
    }
    {
      extension = "heic|HEIC";
      commands = ''
        tmpdir=$(mktemp -d)
        _stp1="$tmpdir/_stp1.png"
        ${libheif}/bin/heif-dec "$infile" "$_stp1" ${redirects.suppress_all} || ${imagemagick}/bin/convert "$infile" "$_stp1" ${redirects.suppress_all}
        if [[ ! -z "$resize" ]]; then
            ${apply_resize "$tmpdir" "$_stp1" "_stp2"}
        else
            _stp2="$_stp1"
        fi
        if [[ "$scrub" == "1" ]]; then
            ${apply_scrub "$tmpdir" "$_stp2" "_stp3"}
        else
            _stp3="$_stp2"
        fi
        mv "$_stp3" "$outfile"
        rm -rf $tmpdir
      '';
    }
    {
      extension = "gif|GIF|svg|SVG";
      commands = ''
        ${printWarn} "NOT IMPLEMENTED YET"
      '';
    }
    {
      extension = "random|RANDOM|rand|RAND";
      commands = ''
        if [[ ! "$infile" =~ ^([^-]+)-([0-9]+)-([0-9]+)\.random$ ]]; then
          ${printErr} "Random inputfile must be of form seed-width-height.random"
          exit 1
        fi
        tmpdir=$(mktemp -d)
        seed="''${BASH_REMATCH[1]}"
        width="''${BASH_REMATCH[2]}"
        height="''${BASH_REMATCH[3]}"
        ${printWarn} "Generating a random ''${width}x''${height} PNG with seed $seed -> ''${outfile}..."
        key=$(printf "%s" "$seed" | sha256sum | awk '{print $1}')
        nbytes=$((width * height * 3))
        dd if=/dev/zero bs=$nbytes count=1 2>/dev/null \
          | ${openssl}/bin/openssl enc -aes-256-ctr -K "$key" -iv 0 \
          > $tmpdir/rand.rgb
        ${imagemagick}/bin/convert -size ''${width}x''${height} -depth 8 rgb:''${tmpdir}/rand.rgb \
          -define png:compression-level=9 \
          -define png:exclude-chunk=all \
          "$outfile"
        rm -r $tmpdir
      '';
    }
  ];
in callPackage ./mkConverter.nix {
  inherit writeArgparseScriptBin color-prints strings;
  inherit name extension usage_str optsWithVarsAndDefaults convOptCmds;
  description = "Generate PNG images from a variety of similar formats.";
}
