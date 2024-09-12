{ writeShellScriptBin, rcrsync, color-prints, redirects, callPackage, python }:
let
  pkgname = "authm";
  description = "Manage secrets.";
  longDescription = "";
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
  printErr = ">&2 ${color-prints}/bin/echo_red";
in (writeShellScriptBin pkgname ''
  if ([[ "$*" == *"refresh"* ]] || [[ "$*" == *"validate"* ]]) && [[ "$*" != *"--help"* ]]; then
    ${rcrsync}/bin/rcrsync copy secrets
  fi
  ${authm}/bin/${pkgname} $@ || { ${printErr} "Authm automatic refresh failed!"; exit 1; }
  if ([[ "$*" == *"refresh"* ]] || [[ "$*" == *"validate"* ]]) && [[ "$*" != *"--help"* ]] && [[ "$*" != *"--headless"* ]]; then
    ${rcrsync}/bin/rcrsync sync secrets
  fi
'') // {
  meta = {
    inherit description longDescription;
    autoGenUsageCmd = "--help";
    subCmds = [ "refresh" "validate" ];
  };
}
