from datetime import datetime

import pytest

from goromail import cli
from goromail.cli import (
    MAIL_EMAIL,
    TEXT_EMAIL,
    classify_sender,
    handle_nutrition_message,
    sender_matches,
)


# The address Lose It! actually sends daily summaries from.
LOSEIT_SENDER = "donotreply@loseit.com"


# --- sender_matches: address-only, domain-aware ---
def test_matches_the_real_loseit_sender():
    assert sender_matches(LOSEIT_SENDER, cli.NUTRITION_SENDERS)


def test_matches_bare_address():
    assert sender_matches("no-reply@loseit.com", ["loseit.com"])


def test_matches_display_name_form():
    assert sender_matches("Lose It! <no-reply@loseit.com>", ["loseit.com"])


def test_matches_subdomain():
    assert sender_matches("bounce@mail.loseit.com", ["loseit.com"])


def test_matches_full_address_pattern():
    assert sender_matches(f"Andrew <{MAIL_EMAIL}>", [MAIL_EMAIL])


def test_is_case_insensitive():
    assert sender_matches("No-Reply@LoseIt.COM", ["loseit.com"])


def test_lookalike_domain_does_not_match():
    # endswith(".loseit.com") must not be fooled by a domain merely ending in it
    assert not sender_matches("spam@notloseit.com", ["loseit.com"])


def test_display_name_spoof_does_not_match():
    # The owner's address in the display name must not grant owner privileges
    spoofed = f'"{MAIL_EMAIL}" <spam@elsewhere.net>'
    assert not sender_matches(spoofed, [MAIL_EMAIL])


def test_empty_and_none_senders():
    assert not sender_matches("", ["loseit.com"])
    assert not sender_matches(None, ["loseit.com"])
    assert not sender_matches("not an address", ["loseit.com"])


def test_empty_pattern_list():
    assert not sender_matches("no-reply@loseit.com", [])


# --- classify_sender: the routing table ---
def test_nutrition_sender_routes_to_nutrition():
    assert classify_sender(f"Lose It! <{LOSEIT_SENDER}>") == "nutrition"
    assert classify_sender(LOSEIT_SENDER) == "nutrition"


def test_owner_email_routes_to_owner():
    assert classify_sender(MAIL_EMAIL) == "owner"


def test_owner_text_routes_to_owner():
    assert classify_sender(TEXT_EMAIL) == "owner"


def test_stranger_routes_to_unknown():
    assert classify_sender("someone@example.com") == "unknown"


def test_missing_from_header_routes_to_unknown():
    assert classify_sender(None) == "unknown"


def test_nutrition_wins_over_owner():
    # Should the owner ever also be a nutrition sender, nutrition must win --
    # that is the branch that cannot reach Notion.
    assert classify_sender(f"forwarder@{cli.NUTRITION_SENDERS[0]}") == "nutrition"


# --- the guarantee: nutrition senders never reach the Notion branches ---
@pytest.mark.parametrize(
    "body",
    [
        "You haven't logged food in 3 days!",  # nag email
        "<html>50% off Lose It! Premium</html>",  # promo
        "Weekly Summary for Monday, March 3",  # wrong report type
        "Daily calorie budget</td><td>2,000</td>",  # daily summary, drifted format
        "",
    ],
)
def test_unparseable_nutrition_mail_is_still_classified_nutrition(body):
    """Body shape must not change the route. This is what keeps a nag email or a
    format change from falling through to the catch-all ITNS Notion branch."""
    assert classify_sender(LOSEIT_SENDER) == "nutrition"
    assert cli.parse_loseit_email(body) is None  # would have hit the catch-all


LOSEIT_HTML = """
<html><body>
<h1>Daily Summary for Monday, March 3</h1>
<table>
  <tr><td>Daily calorie budget</td><td align="right">2,000</td></tr>
  <tr><td>Food calories consumed</td><td align="right">1,850</td></tr>
</table>
</body></html>
"""


class FakeMessage:
    def __init__(self, raw_text, sender=f"Lose It! <{LOSEIT_SENDER}>"):
        self.raw_text = raw_text
        self.sender = sender
        self.trashed = False

    def moveToTrash(self):
        self.trashed = True


@pytest.fixture
def logged():
    return []


@pytest.fixture
def reported(monkeypatch):
    """Capture survey submissions instead of dialing the tactical server."""
    calls = []
    monkeypatch.setattr(
        cli,
        "report_eating_discipline_to_tactical",
        lambda port, date, level: calls.append((port, date, level)),
    )
    return calls


DATE = datetime(2026, 3, 3, 9, 0)


def test_parsed_summary_reports_and_trashes(logged, reported):
    msg = FakeMessage(LOSEIT_HTML)
    assert handle_nutrition_message(msg, DATE, 60060, False, logged.append) is True
    # 1,850 consumed vs 2,000 budget -> surplus -150 -> full credit, no nutrients
    assert reported == [(60060, datetime(2026, 3, 3), 2)]
    assert msg.trashed


def test_summary_year_comes_from_the_email_date(logged, reported):
    # Lose It! omits the year, so it is taken from the message's own Date header
    msg = FakeMessage(LOSEIT_HTML)
    handle_nutrition_message(msg, datetime(2019, 3, 3), 60060, False, logged.append)
    assert reported[0][1].year == 2019


def test_unparseable_mail_is_trashed_without_reporting(logged, reported):
    msg = FakeMessage("You haven't logged food in 3 days!")
    assert handle_nutrition_message(msg, DATE, 60060, False, logged.append) is False
    assert reported == []
    assert msg.trashed
    assert any("Unparsed nutrition email" in line for line in logged)


def test_dry_run_neither_reports_nor_trashes(logged, reported):
    msg = FakeMessage(LOSEIT_HTML)
    assert handle_nutrition_message(msg, DATE, 60060, True, logged.append) is True
    assert reported == []
    assert not msg.trashed


def test_dry_run_does_not_trash_unparseable_mail(logged, reported):
    msg = FakeMessage("nothing parseable here")
    assert handle_nutrition_message(msg, DATE, 60060, True, logged.append) is False
    assert not msg.trashed


def test_log_lines_do_not_trip_the_notion_grep(logged, reported):
    """ats-mailman greps postfix.log for "notion" (case-insensitively) to decide
    whether to re-run annotate-triage-pages. Nutrition lines must not match."""
    handle_nutrition_message(FakeMessage(LOSEIT_HTML), DATE, 60060, False, logged.append)
    handle_nutrition_message(FakeMessage("junk"), DATE, 60060, False, logged.append)
    assert logged
    assert not any("notion" in line.lower() for line in logged)
