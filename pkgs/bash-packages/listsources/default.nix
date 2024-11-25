{ writeArgparseScriptBin, color-prints }:
let
  pkgname = "listsources";
  printErr = "${color-prints}/bin/echo_red";
  printWht = "${color-prints}/bin/echo_white";
in (writeArgparseScriptBin pkgname ''
  usage: ${pkgname}

  List git information for all sources in a workspace. Must be run 
  within in a workspace created by setupws.
'' [ ] ''
  set -eo pipefail
  if [[ -z "$WSROOT" ]]; then
      ${printErr} "ERROR: \$WSROOT not set. Are you in a directory set up by setupws?"
      exit 1
  fi
  cd "$WSROOT/sources"
  for proj in *; do
      if [[ -d $proj ]] && [[ -d $proj/.git ]]; then
          ${printWht} "======= $proj ======="
          cd $proj
          ${printWht} $(git log | head -1)
          git status
          cd ..
          echo ""
      fi 
  done
'') // {
  meta = {
    description =
      "Get the Git info about all sources in a `devshell` workspace.";
    longDescription = ''
      **This command needs to be run with a** `devshell` workspace created with `setupws`.

      ```
      usage: listsources

      List git information for all sources in a workspace. Must be run 
      within in a workspace created by setupws.
      ```
    '';
  };
}
