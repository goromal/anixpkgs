import argparse
import os
import json
import pandas as pd
import matplotlib.pyplot as plt

def main():
    parser = argparse.ArgumentParser(description="Budget report generator", formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument("-c", "--config", default=os.path.expanduser("~/configs/budgets.json"), help="JSON config file with budget names and limits")
    parser.add_argument("transactions", help="CSV file of transactions (exported from Mint)")
    args = parser.parse_args()

    df = pd.read_csv(args.transactions)
    with open(args.config, "r") as configfile:
        categories_of_interest = json.loads(configfile.read())
    num_categories = len(categories_of_interest)

    df['Date'] = pd.to_datetime(df['Date'])
    df = df.drop("Original Description", axis=1)
    df = df.drop("Account Name", axis=1)
    df = df.drop("Labels", axis=1)
    df = df.drop("Notes", axis=1)
    category_dfs = {}

    for category, raw_data in df.groupby("Category"):
        if category in categories_of_interest.keys():
            raw_data.sort_values("Date", inplace=True)
            
            category_data = pd.DataFrame(columns=[
                "Date",
                "Debit",
                "Credit","Expense",
                "AbsExpense",
                "CumulativeDebit",
                "CumulativeCredit",
                "TotalExpense",
                "TotalAbsExpense"
            ])
            cum_debit = 0.0
            cum_credit = 0.0
            total_expense = 0.0
            for date, day_data in raw_data.groupby("Date"):
                debit = day_data.loc[day_data["Transaction Type"] == "debit", "Amount"].sum()
                credit = day_data.loc[day_data["Transaction Type"] == "credit", "Amount"].sum()
                expense = debit - credit
                absexpense = max(expense, 0.)
                cum_debit += debit
                cum_credit += credit
                total_expense = cum_debit - cum_credit
                total_absexpense = max(total_expense, 0.)
                category_data.loc[date] = [
                    date,
                    debit,
                    credit,
                    expense,
                    absexpense,
                    cum_debit,
                    cum_credit,
                    total_expense,
                    total_absexpense
                ]
            category_dfs[category] = category_data

    _, ax = plt.subplots(num_categories, 1)
    for i, category in enumerate(category_dfs.keys()):
        ax[i].plot([category_dfs[category]["Date"].head(1), category_dfs[category]["Date"].tail(1)], [categories_of_interest[category], categories_of_interest[category]], "r--")
        ax[i].bar(category_dfs[category]["Date"], category_dfs[category]["Expense"], color="black")
        ax[i].plot(category_dfs[category]["Date"], category_dfs[category]["TotalExpense"], "k-", linewidth=2.)
        ax[i].plot([category_dfs[category]["Date"].head(1), category_dfs[category]["Date"].tail(1)], [0., categories_of_interest[category]], "r--")
        ax[i].set_ylabel(category)
        ax[i].grid()
    plt.show()

if __name__ == "__main__":
    main()
