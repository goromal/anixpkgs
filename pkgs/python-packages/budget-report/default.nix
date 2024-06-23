{ callPackage, pytestCheckHook, buildPythonPackage, gspread, fuzzywuzzy
, easy-google-auth, gmail-parser }:
callPackage ../pythonPkgFromScript.nix {
  pname = "budget_report";
  version = "1.0.0";
  description = "Generate a budget report.";
  script-file = ./report.py;
  inherit pytestCheckHook buildPythonPackage;
  propagatedBuildInputs = [ gspread fuzzywuzzy easy-google-auth gmail-parser ];
  checkPkgs = [ ];
  longDescription = "";
  subCmds = [
    "transactions-process"
    "transactions-status"
    "transactions-upload"
    "transactions-bin"
  ];
}
