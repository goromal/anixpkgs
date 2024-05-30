import logging
import click
import sys
import os
import json
# import pandas as pd
import gspread
# from fuzzywuzzy import fuzz

from easy_google_auth.auth import getGoogleCreds
from gmail_parser.defaults import GmailParserDefaults as GPD

@click.group()
@click.pass_context
@click.option(
    "--secrets-json",
    "secrets_json",
    type=click.Path(exists=True),
    default=GPD.GMAIL_SECRETS_JSON,
    show_default=True,
    help="Client secrets file.",
)
@click.option(
    "--refresh-file",
    "refresh_file",
    type=click.Path(),
    default=GPD.GMAIL_REFRESH_FILE,
    show_default=True,
    help="Refresh file (if it exists).",
)
@click.option(
    "--config-json",
    "config_json",
    type=click.Path(exists=True),
    default=os.path.expanduser("~/configs/budget-tool.json"),
    show_default=True,
    help="Budget tool config file.",
)
@click.option(
    "--enable-logging",
    "enable_logging",
    type=bool,
    default=GPD.ENABLE_LOGGING,
    show_default=True,
    help="Whether to enable logging.",
)
def cli(ctx: click.Context, secrets_json, refresh_file, config_json, enable_logging):
    """Tools for Budget Management."""
    if enable_logging:
        logging.getLogger().addHandler(logging.StreamHandler(sys.stdout))
    try:
        with open(config_json, "r") as configfile:
            config = json.load(configfile)
        sheet = gspread.authorize(getGoogleCreds(
                secrets_json,
                refresh_file,
                headless=True,
            )).open_by_key(config["spreadsheetId"])
        config_data = sheet.worksheet(config["configSheetName"]).get_all_records()
        ctx.obj = {
            "config": config,
            "sheet": sheet,
            "config_data": config_data,
        }
    except Exception as e:
        logging.error(f"Program error: {e}")
        sys.stderr.write(f"Program error: {e}")
        exit(1)

@cli.command()
@click.pass_context
def transactions_status(ctx: click.Context):
    """Get the status of raw transactions."""
    transactions_sheet = None
    for config_datum in ctx.obj["config_data"]:
        if config_datum["Category"] == "_TRANSACTIONS_":
            transactions_sheet = config_datum["Sheet"]
            break
    if transactions_sheet is None:
        raise Exception("Unable to find sheet metadata for transactions")
    transactions_data = ctx.obj["sheet"].worksheet(transactions_sheet).get_all_records()
    num_processed = sum([1 for t in transactions_data if t["Processed?"] == "X"])
    print(f"{num_processed} / {len(transactions_data)} transactions processed.")

@cli.command()
@click.pass_context
@click.option(
    "--raw-csv",
    "raw_csv",
    type=click.Path(exists=True),
    required=True,
    help="Raw CSV file with transactions.",
)
@click.option(
    "--account",
    "account",
    type=str,
    required=True,
    help="Account type from the config file.",
)
def transactions_status(ctx: click.Context, raw_csv, account):
    """Upload missing raw transactions to the budget sheet"""
    pass # TODO

# Assuming you have already set up the Google Sheets API object named 'service'

# Function to fetch data from Google Sheets
# def fetch_google_sheets_data(service, spreadsheet_id, range_name):
#     result = service.spreadsheets().values().get(spreadsheetId=spreadsheet_id, range=range_name).execute()
#     values = result.get('values', [])

#     if not values:
#         print('No data found.')
#         return None
#     else:
#         df = pd.DataFrame(values[1:], columns=values[0])
#         return df

# # Define a function to perform fuzzy string matching and group transactions
# def group_transactions(df):
#     groups = {}
#     for index, row in df.iterrows():
#         matched = False
#         for group_name, group_data in groups.items():
#             for transaction in group_data:
#                 if fuzz.partial_ratio(row['transaction'], transaction) > 80:  # Adjust threshold as needed
#                     groups[group_name].append(row['transaction'])
#                     matched = True
#                     break
#             if matched:
#                 break
#         if not matched:
#             groups[row['transaction']] = [row['transaction']]
#     return groups

# # Group transactions
# transaction_groups = group_transactions(df)

# # Calculate total amount for each group
# group_totals = {}
# for group_name, transactions in transaction_groups.items():
#     group_totals[group_name] = df[df['transaction'].isin(transactions)]['amount'].astype(float).sum()

# # Print the results
# for group_name, total_amount in group_totals.items():
#     print(f"Group: {group_name}, Total Amount: {total_amount}")

def main():
    cli()

if __name__ == "__main__":
    main()
