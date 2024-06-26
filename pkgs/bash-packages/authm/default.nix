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
  bisync = ''
    if ([[ "$*" == *"refresh"* ]] || [[ "$*" == *"validate"* ]]) && [[ "$*" != *"--help" ]]; then
      ${rcrsync}/bin/rcrsync sync secrets
    fi
  '';
  printErr = ">&2 ${color-prints}/bin/echo_red";
in (writeShellScriptBin pkgname ''
  ${bisync}
  ${authm}/bin/${pkgname} $@ || { ${printErr} "Authm automatic refresh failed!"; exit 1; }
  ${bisync}
'') // {
  meta = {
    inherit description longDescription;
    autoGenUsageCmd = "--help";
    subCmds = [ "refresh" "validate" ];
  };
}
