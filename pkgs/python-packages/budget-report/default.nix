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
  longDescription = ''
    ```
    Usage: budget_report [OPTIONS] COMMAND [ARGS]...

      Tools for Budget Management.

    Options:
      --secrets-json PATH       Client secrets file.  [default: /home/atorgesen/se
                                crets/google/client_secrets.json]
      --refresh-file PATH       Refresh file (if it exists).  [default:
                                /home/atorgesen/secrets/google/refresh.json]
      --config-json PATH        Budget tool config file.  [default:
                                /home/atorgesen/configs/budget-tool.json]
      --enable-logging BOOLEAN  Whether to enable logging.  [default: False]
      --help                    Show this message and exit.

    Commands:
      transactions-bin      Bin all transactions from a category sheet.
      transactions-process  Process raw transactions.
      transactions-status   Get the status of raw transactions.
      transactions-upload   Upload missing raw transactions to the budget sheet.
    ```
  '';
}
