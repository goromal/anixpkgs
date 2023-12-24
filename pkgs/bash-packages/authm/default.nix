{ writeShellScriptBin, color-prints, redirects, callPackage, python }:
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
    SECRETS_DIR="$HOME/secrets"
    if [[ "$*" == *"refresh"* ]] || [[ "$*" == *"validate"* ]]; then
      if [[ ! -d "$SECRETS_DIR" ]]; then
        >&2 ${color-prints}/bin/echo_red "Secrets directory $SECRETS_DIR not present. Exiting."
        exit 1
      fi
      ${color-prints}/bin/echo_cyan "Syncing the secrets directory..."
      _success=1
      rclone bisync dropbox:secrets "$SECRETS_DIR" ${redirects.suppress_all} || { _success=0; }
      if [[ "$_success" == "0" ]]; then
        ${color-prints}/bin/echo_yellow "Bisync failed; attempting with --resync..."
        _success=1
        rclone bisync --resync dropbox:secrets "$SECRETS_DIR" ${redirects.suppress_all} || { _success=0; }
        if [[ "$_success" == "0" ]]; then
          >&2 ${color-prints}/bin/echo_red "Bisync retry failed. Exiting."
          exit 1
        fi
      fi
    fi
  '';
in (writeShellScriptBin pkgname ''
  ${bisync}
  ${authm}/bin/${pkgname} $@
  ${bisync}
'') // {
  meta = { inherit description longDescription; };
}
