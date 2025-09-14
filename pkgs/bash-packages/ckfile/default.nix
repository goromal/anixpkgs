{ writeArgparseScriptBin, color-prints, pv }:
let
  pkgname = "ckfile";
  printErr = "${color-prints}/bin/echo_red";
  printGrn = "${color-prints}/bin/echo_green";
in (writeArgparseScriptBin pkgname ''
  usage: ${pkgname} [opts] file

  Verify the checksum of a file.

  Options:
    -c CHECKSUM     Expected (md5sum) checksum of the file. Will return PASS|FAIL.
'' [{
  var = "EXPECTED_MD5";
  isBool = false;
  default = "";
  flags = "-c";
}] ''
  if [[ -z "$1" ]] || [[ ! -f "$1" ]]; then
    ${printErr} "Must specify a file that exists."
    exit 1
  fi
  COMPUTED_MD5=$(${pv}/bin/pv "$1" | md5sum | awk '{print $1}')
  if [[ -z "$EXPECTED_MD5" ]]; then
    ${printGrn} "$COMPUTED_MD5"
    exit
  fi
  if [ "$COMPUTED_MD5" = "$EXPECTED_MD5" ]; then
    ${printGrn} "PASS"
  else
    ${printErr} "FAIL: $COMPUTED_MD5"
    exit 1
  fi
'') // {
  meta = {
    description = "Verify the checksum of a file.";
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
