import pytest

from budget_report.cli import parse_amount, parse_raw_transactions

CITI = {"Account": "Citi", "StartRow": 1, "Date": 1, "Description": 2, "Amount": [3, 4], "NegateAmount": False}
CHASE_DB = {"Account": "CHASE_DB", "StartRow": 1, "Date": 1, "Description": 2, "Amount": [3], "NegateAmount": True}
CITI_HEADER = ["Status", "Date", "Description", "Debit", "Credit", "Member Name"]


@pytest.mark.parametrize(
    "text, expected",
    [
        ("55.82", 55.82),
        ("-369.95", -369.95),
        ("$ 67.31", 67.31),
        (" -$ 491.80", -491.80),
        ("$ 3,156.80", 3156.80),
        ("", None),
        ("  ", None),
    ],
)
def test_parse_amount(text, expected):
    assert parse_amount(text) == expected


def test_parse_amount_rejects_text():
    with pytest.raises(ValueError):
        parse_amount("N/A")


def test_citi_dollar_format():
    rows = [
        CITI_HEADER,
        ["Cleared", "10/20/2026", "COSTCO GAS #1772", "$ 67.31", "", "A"],
        ["Cleared", "10/05/2026", "ONLINE PAYMENT, THANK YOU", "", " -$ 491.80", "A"],
    ]
    transactions, errors = parse_raw_transactions(rows, "Citi", CITI)
    assert errors == []
    assert transactions == [
        ("Citi", "10/20/2026", "COSTCO GAS #1772", 67.31),
        ("Citi", "10/05/2026", "ONLINE PAYMENT, THANK YOU", -491.80),
    ]


def test_unquoted_thousands_comma_is_an_error_not_a_wrong_amount():
    # Citi writes "$ 3,156.80" unquoted, which splits the amount across cells.
    rows = [
        CITI_HEADER,
        ["Cleared", "04/19/2026", "COSTCO TRAVEL SEATTLE WA", "$ 3", "156.80", "", "A"],
    ]
    transactions, errors = parse_raw_transactions(rows, "Citi", CITI)
    assert transactions == []
    assert len(errors) == 1 and "expected 6 columns, got 7" in errors[0]


def test_trailing_empty_cell_and_negation():
    rows = [
        ["Details", "Posting Date", "Description", "Amount", "Type", "Balance", "Check or Slip #"],
        ["DEBIT", "10/22/2026", "WASTE  MANAGEMENT", "-80.55", "ACH_DEBIT", "100.00", "", ""],
    ]
    transactions, errors = parse_raw_transactions(rows, "CHASE_DB", CHASE_DB)
    assert errors == []
    assert transactions == [("CHASE DB", "10/22/2026", "WASTE MANAGEMENT", 80.55)]


def test_unreadable_or_missing_amount_is_an_error():
    rows = [
        CITI_HEADER,
        ["Cleared", "10/20/2026", "BAD", "N/A", "", "A"],
        ["Cleared", "10/21/2026", "EMPTY", "", "", "A"],
    ]
    transactions, errors = parse_raw_transactions(rows, "Citi", CITI)
    assert transactions == []
    assert len(errors) == 2


def test_blank_lines_are_ignored():
    rows = [CITI_HEADER, [], ["Cleared", "10/20/2026", "X", "1.00", "", "A"], [""]]
    transactions, errors = parse_raw_transactions(rows, "Citi", CITI)
    assert errors == []
    assert len(transactions) == 1
