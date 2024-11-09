{ writeArgparseScriptBin, color-prints }:
let
  pkgname = "anix-changelog-compare";
  printErr = "${color-prints}/bin/echo_red";
  printYlw = "${color-prints}/bin/echo_yellow";
  printGrn = "${color-prints}/bin/echo_green";
in (writeArgparseScriptBin pkgname ''
  usage: ${pkgname} anixpkgs_FROM anixpkgs_TO

  Compare the changelogs of two instances of anixpkgs.
'' [ ] ''
  if [[ -z "$1" ]] || [[ ! -d "$1" ]]; then
    ${printErr} "Must specify a valid FROM anixpkgs instance."
    exit 1
  fi
  if [[ -z "$2" ]] || [[ ! -d "$2" ]]; then
    ${printErr} "Must specify a valid TO anixpkgs instance."
    exit 1
  fi
  anixpkgs_FROM="$1"
  anixpkgs_TO="$2"
  tmppath=$(mktemp -d)
  if [[ -d "$anixpkgs_FROM/changes" ]]; then
    ls -1 "$anixpkgs_FROM/changes" | sort > "$tmppath/from_files.txt"
  else
    touch "$tmppath/from_files.txt"
  fi
  if [[ -d "$anixpkgs_TO/changes" ]]; then
    ls -1 "$anixpkgs_TO/changes" | sort > "$tmppath/to_files.txt"
  else
    touch "$tmppath/to_files.txt"
  fi
  if [[ -d "$anixpkgs_FROM/changes" ]]; then
    ${printYlw} "REVERTED changes:"
    comm -23 "$tmppath/from_files.txt" "$tmppath/to_files.txt" | xargs -I {} cat $anixpkgs_FROM/changes/{}
  fi
  if [[ -d "$anixpkgs_TO/changes" ]]; then
    ${printGrn} "NEW changes:"
    comm -13 "$tmppath/from_files.txt" "$tmppath/to_files.txt" | xargs -I {} cat $anixpkgs_TO/changes/{}
  fi
  rm -rf "$tmppath"
'') // {
  meta = {
    description = "Compare the changelogs of two instances of anixpkgs.";
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
