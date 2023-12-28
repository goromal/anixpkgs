{ writeShellScriptBin, rcrsync, color-prints, redirects, callPackage, python }:
let
  pkgname = "authm";
  description = "Manage secrets.";
  longDescription = ''
    ```
    Usage: ${pkgname} [OPTIONS] COMMAND [ARGS]...

      Manage secrets.

    Options:
      --help  Show this message and exit.

    Commands:
      refresh   Refresh all auth tokens one-by-one.
      validate  Validate the secrets files present on the filesystem.

    NOTE: This program will perform a bi-directional sync of the ~/secrets directory
    before and after the selected command.
    ```
  '';
  authm = with python.pkgs;
    (callPackage ../../python-packages/pythonPkgFromScript.nix {
      pname = pkgname;
      version = "1.0.0";
      inherit description longDescription;
      script-file = ./authm.py;
      inherit pytestCheckHook buildPythonPackage;
      propagatedBuildInputs = [
        click
        colorama
        easy-google-auth
        gmail-parser
        task-tools
        wiki-tools
        book-notes-sync
      ];
      checkPkgs = [ ];
    });
  bisync = ''
    if [[ "$*" == *"refresh"* ]] || [[ "$*" == *"validate"* ]]; then
      ${rcrsync}/bin/rcrsync sync secrets
    fi
  '';
  printErr = ">&2 ${color-prints}/bin/echo_red";
in (writeShellScriptBin pkgname ''
  lockfile=$HOME/.authm-lock
  timeout_secs=30
  wait_secs=0
  while [[ -f "$lockfile" ]] && (( wait_secs < timeout_secs )); do
    echo "Waiting for lockfile to clear..."
    wait_secs=$(( wait_secs+1 ))
    sleep 1
  done
  if [[ -f "$lockfile" ]]; then
    ${printErr} "Timed out waiting for lockfile to clear. Exiting."
    exit 1
  fi
  touch "$lockfile"
  ${bisync}
  ${authm}/bin/${pkgname} $@ || { ${printErr} "Authm automatic refresh failed!"; rm "$lockfile"; exit 1; }
  ${bisync}
  rm "$lockfile"
'') // {
  meta = { inherit description longDescription; };
}
