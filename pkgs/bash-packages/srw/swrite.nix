{ writeArgparseScriptBin, color-prints, sunnyside, file, redirects }:
let
  pkgname = "swrite";
  cpath = "/dev/shm/c";
  printErr = "${color-prints}/bin/echo_red";
in (writeArgparseScriptBin pkgname ''
  usage: ${pkgname} [opts] file

  Read a secure file.

  Options:
    -c /path/to/cipher (default: ${cpath})
'' [{
  var = "CIPHER";
  isBool = false;
  default = cpath;
  flags = "-c";
}] ''
  if [[ -z "$1" ]]; then
    ${printErr} "Please provide a file."
    exit 1
  elif [[ "$1" == *.tyz ]]; then
    ${printErr} "Please provide a file that is not already scrambled."
    exit 1
  elif [[ ! -f "$1" ]]; then
    ${printErr} "Please provide a file that exists."
    exit 1
  elif [[ ! -f "$CIPHER" ]]; then
    ${printErr} "Please provide a cipher that exists."
    exit 1
  fi

  cchar=$([ -s "$CIPHER" ] && ${file}/bin/file --mime-type -b "$CIPHER" | grep -q '^text/' && cat "$CIPHER" || echo -n " ")
  ${sunnyside}/bin/sunnyside --target "$1" --shift 0 --key "$cchar" ${redirects.suppress_all}
  echo "''${1}.tyz"
'') // {
  meta = {
    description = "Write secure files.";
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
