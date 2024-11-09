# budget_report

Generate a budget report.


## Usage (Auto-Generated)

```bash
Usage: budget_report [OPTIONS] COMMAND [ARGS]...

  Tools for Budget Management.

Options:
  --secrets-json PATH       Client secrets file.  [default:
                            ~/secrets/google/client_secrets.json]
  --refresh-file PATH       Refresh file (if it exists).  [default:
                            ~/secrets/google/refresh.json]
  --config-json PATH        Budget tool config file.  [default:
                            ~/configs/budget-tool.json]
  --enable-logging BOOLEAN  Whether to enable logging.  [default: False]
  --help                    Show this message and exit.

Commands:
  transactions-bin      Bin all transactions from a category sheet.
  transactions-process  Process raw transactions.
  transactions-status   Get the status of raw transactions.
  transactions-upload   Upload missing raw transactions to the budget sheet.



Usage: budget_report transactions-process [OPTIONS]

  Process raw transactions.

Options:
  --dry-run  Activate dry run mode.
  --help     Show this message and exit.



Usage: budget_report transactions-status [OPTIONS]

  Get the status of raw transactions.

Options:
  --help  Show this message and exit.



Usage: budget_report transactions-upload [OPTIONS]

  Upload missing raw transactions to the budget sheet.

Options:
  --raw-csv PATH  Raw CSV file with transactions.  [required]
  --account TEXT  Account type from the config file.  [required]
  --dry-run       Activate dry run mode.
  --help          Show this message and exit.



Usage: budget_report transactions-bin [OPTIONS]

  Bin all transactions from a category sheet.

Options:
  --category TEXT  Category from the Config sheet.  [required]
  --help           Show this message and exit.

```

