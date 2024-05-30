{ callPackage, pytestCheckHook, buildPythonPackage, gspread,
# fuzzywuzzy,
easy-google-auth, gmail-parser }:
callPackage ../pythonPkgFromScript.nix {
  pname = "budget_report";
  version = "1.0.0";
  description = "Generate a budget report.";
  # script-file = ./report.py;
  script-file = ./new.report.py;
  inherit pytestCheckHook buildPythonPackage;
  propagatedBuildInputs = [ gspread 
    # fuzzywuzzy 
    easy-google-auth gmail-parser ];
  checkPkgs = [ ];
  longDescription = ''
    ```
    usage: budget_report [-h] [-c CONFIG] transactions

    Budget report generator

    positional arguments:
    transactions          CSV file of transactions (exported from Mint)

    optional arguments:
    -h, --help            show this help message and exit
    -c CONFIG, --config CONFIG
                            JSON config file with budget names and limits (default:
                            /data/andrew/configs/budgets.json)
    ```
  '';
}
