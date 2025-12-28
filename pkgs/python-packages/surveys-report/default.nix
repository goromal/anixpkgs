{ callPackage, pytestCheckHook, buildPythonPackage, aapis-py, grpcio
, easy-google-auth, gspread, click, gmail-parser }:
callPackage ../pythonPkgFromScript.nix {
  pname = "surveys_report";
  version = "1.0.0";
  description = "Generate survey reports.";
  script-file = ./report.py;
  inherit pytestCheckHook buildPythonPackage;
  propagatedBuildInputs =
    [ aapis-py grpcio easy-google-auth gspread click gmail-parser ];
  checkPkgs = [ ];
  longDescription = "";
  subCmds = [ "list-results" "upload-results" ];
}
