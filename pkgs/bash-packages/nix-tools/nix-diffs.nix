{ writeArgparseScriptBin, color-prints, nix-diff }:
let
  pkgname = "nix-diffs";
  description =
    "Diff the Nix hashes of two closures or packages in nicely-formatted diffed text files (with ordering mostly preserved).";
  long-description = ''
    usage: ${pkgname} derivation1 derivation2 out_dir
  '';
  usage_str = ''
    ${long-description}
    ${description}
  '';
  printErr = "${color-prints}/bin/echo_red";
in (writeArgparseScriptBin pkgname usage_str [ ] ''
  if [[ -z "$1" ]]; then
      ${printErr} "derivation1 not specified."
      exit 1
  elif [[ -z "$2" ]]; then
      ${printErr} "derivation2 not specified."
      exit 1
  elif [[ -z "$3" ]]; then
      ${printErr} "out_dir not specified."
      exit 1
  fi
  OUT_DIR=$3
  ${nix-diff}/bin/nix-diff "$1" "$2" | awk '/^ *[\+-] \/nix\/store/ { print $0 }' | sed 's/ *//' | sed 's/:{out}//' | sed 's/[+-]//' | tail -n +3 > /tmp/nix-diff.txt
  while read -r LEFT_DRV; do
      read -r RIGHT_DRV
      LEFT_OUT_FILE=$(echo 'l-'$(echo $LEFT_DRV | sed 's/.*-//'))
      RIGHT_OUT_FILE=$(echo 'r-'$(echo $RIGHT_DRV | sed 's/.*-//'))
      cat $LEFT_DRV | sed 's/\\n/\n/g' | sed 's/),(/),\n(/g' | sed 's/\],\[/\],\n\[/g' | sed 's/},{/},\n{/g' | sort > $OUT_DIR/$LEFT_OUT_FILE
      cat $RIGHT_DRV | sed 's/\\n/\n/g' | sed 's/),(/),\n(/g' | sed 's/\],\[/\],\n\[/g' | sed 's/},{/},\n{/g' | sort > $OUT_DIR/$RIGHT_OUT_FILE
      vim -d $OUT_DIR/$LEFT_OUT_FILE $OUT_DIR/$RIGHT_OUT_FILE
  done < /tmp/nix-diff.txt
'') // {
  meta = {
    inherit description;
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
