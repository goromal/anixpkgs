import pandas as pd
from fuzzywuzzy import fuzz

# Assuming you have already set up the Google Sheets API object named 'service'

# Function to fetch data from Google Sheets
def fetch_google_sheets_data(service, spreadsheet_id, range_name):
    result = service.spreadsheets().values().get(spreadsheetId=spreadsheet_id, range=range_name).execute()
    values = result.get('values', [])

    if not values:
        print('No data found.')
        return None
    else:
        df = pd.DataFrame(values[1:], columns=values[0])
        return df

# Define a function to perform fuzzy string matching and group transactions
def group_transactions(df):
    groups = {}
    for index, row in df.iterrows():
        matched = False
        for group_name, group_data in groups.items():
            for transaction in group_data:
                if fuzz.partial_ratio(row['transaction'], transaction) > 80:  # Adjust threshold as needed
                    groups[group_name].append(row['transaction'])
                    matched = True
                    break
            if matched:
                break
        if not matched:
            groups[row['transaction']] = [row['transaction']]
    return groups

# Group transactions
transaction_groups = group_transactions(df)

# Calculate total amount for each group
group_totals = {}
for group_name, transactions in transaction_groups.items():
    group_totals[group_name] = df[df['transaction'].isin(transactions)]['amount'].astype(float).sum()

# Print the results
for group_name, total_amount in group_totals.items():
    print(f"Group: {group_name}, Total Amount: {total_amount}")
