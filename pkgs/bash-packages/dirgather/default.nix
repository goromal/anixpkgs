{ writeArgparseScriptBin, color-prints, strings }:
let
  pkgname = "dirgather";
  printErr = "${color-prints}/bin/echo_red";
  printGrn = "${color-prints}/bin/echo_green";
in (writeArgparseScriptBin pkgname ''
  usage: ${pkgname} [options] rootdir gatherdir

  Recursively take all files in rootdir's tree and gather them in a new gatherdir. Subsequently, clean up all empty directories in rootdir.

  Options:
    --dry-run      Perform a dry run
'' [{
  var = "dry_run";
  isBool = true;
  default = "0";
  flags = "--dry-run";
}] ''
  set -e
  if [[ -z "$1" ]]; then
    ${printErr} "rootdir not provided."
    exit 1
  fi
  rootdir="$1"
  if [[ -z "$2" ]]; then
    ${printErr} "gatherdir not provided."
    exit 1
  fi
  gatherdir="$2"
  fcount=$(find ''${rootdir} -depth -type f -not -path "./''${gatherdir}/*" | wc -l)
  if [[ "$dry_run" == "1" ]]; then
    ${printGrn} "[Dry Run] Move $fcount files into ''${gatherdir}."
    exit
  fi
  mkdir -p "$gatherdir"
  ${printGrn} "Moving $fcount files into ''${gatherdir}."
  for f in $(find ''${rootdir} -depth -type f -not -path "./''${gatherdir}/*"); do
    bname=`${strings.getBasename} "$f"`
    if [[ -f "$gatherdir/$bname" ]]; then
      bdir=`${strings.getBaseDir} "$f"`
      mv "$f" "$gatherdir/from.''${bdir}.''${bname}"
    else
      mv "$f" "$gatherdir"
    fi
  done
  ${printGrn} "Cleaning up empty directories inside of $rootdir"
  find "$rootdir" -type d -empty -delete
'') // {
  meta = {
    description =
      "Gather all files in a directory tree into a single directory.";
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
