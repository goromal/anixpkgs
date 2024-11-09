{ writeArgparseScriptBin, strings }:
let pkgname = "fixfname";
in (writeArgparseScriptBin pkgname ''
  usage: ${pkgname} FILE

  Replace spaces and remove [], () characters from a filename (in place).
'' [ ] ''
  fname="$1"
  pt1=$(${strings.dashSpaces} "$fname")
  pt2=$(${strings.removeListNotation} "$pt1")
  newfname="$pt2"
  echo "$fname -> $newfname"
  mv "$fname" "$newfname"
'') // {
  meta = {
    description = "Unix-ify filenames.";
    longDescription = ''
      ```
      usage: fixfname FILE

      Replace spaces and remove [], () characters from a filename (in place).
      ```
    '';
  };
}
