import click
import re
import os
import sys
import json
import requests
from colorama import Fore, Style
from datetime import datetime
from pathlib import Path
from gmail_parser.corpus import GBotCorpus, JournalCorpus
from gmail_parser.defaults import GmailParserDefaults as GPD
from wiki_tools.wiki import WikiTools
from wiki_tools.defaults import WikiToolsDefaults as WTD
from task_tools.manage import TaskManager
from task_tools.defaults import TaskToolsDefaults as TTD

MAIL_EMAIL = "andrew.torgesen@gmail.com"
TEXT_EMAIL = "6612105214@vzwpix.com"


def create_notion_bulleted_list(data, level=0):
    if not isinstance(data, list):
        raise ValueError("Input data must be a list.")
    notion_blocks = []
    for item in data:
        if isinstance(item, list):
            nested_blocks = create_notion_bulleted_list(item, level + 1)
            if notion_blocks:
                notion_blocks[-1]["bulleted_list_item"]["children"] = nested_blocks
            else:
                raise ValueError("Nested list structure is invalid.")
        else:
            block = {
                "object": "block",
                "type": "bulleted_list_item",
                "bulleted_list_item": {
                    "rich_text": [{"type": "text", "text": {"content": str(item)}}]
                },
            }
            notion_blocks.append(block)
    return notion_blocks


def append_text_to_notion_page(token, id, msg, text):
    ps = [p for p in text.split("\n") if p.strip()]
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Notion-Version": "2022-06-28",
    }
    data = {
        "children": create_notion_bulleted_list(
            [ps[0], ps[1:]] if len(ps) > 1 else [ps[0]]
        )
    }
    url = f"https://api.notion.com/v1/blocks/{id}/children"
    response = requests.patch(url, json=data, headers=headers)
    if response.status_code == 200:
        msg.moveToTrash()
    else:
        sys.stderr.write(f"Program error: {response.status_code}, {response.text}")
        exit(1)


def process_keyword(
    text, datestr, keyword, notion_api_token, notion_page_id, msg, dry_run, logfile=None
):
    n = len(keyword)
    if text[: (n + 1)].lower() == f"{keyword}:":
        matter = text[(n + 1) :].strip()
        print(f"  {keyword} offload item: {matter}")
        if matter[:3].lower() == "p0:":
            item = f"[::::{datestr}::::] {matter[3:].strip()}"
        elif matter[:3].lower() == "p1:":
            item = f"[:::{datestr}:::] {matter[3:].strip()}"
        else:
            item = f"[**{datestr}**] {matter.strip()}"
        if logfile is not None:
            logfile.write(f"Notion:{keyword} entry\n")
        if not dry_run:
            append_text_to_notion_page(notion_api_token, notion_page_id, msg, item)
        return True
    elif text[: (n + 6)].lower() == f"sort {keyword}.":
        matter = text[(n + 6) :].strip()
        print(f"  {keyword} offload item: {matter}")
        if matter[:3].lower() == "p0:":
            item = f"[::::{datestr}::::] {matter[3:].strip()}"
        elif matter[:3].lower() == "p1:":
            item = f"[:::{datestr}:::] {matter[3:].strip()}"
        else:
            item = f"[**{datestr}**] {matter.strip()}"
        if logfile is not None:
            logfile.write(f"Notion:{keyword} entry\n")
        if not dry_run:
            append_text_to_notion_page(notion_api_token, notion_page_id, msg, item)
        return True
    return False


def add_journal_entry_to_wiki(wiki, msg, date, text):
    new_entry = (date, date.strftime("%B %d"), "FIXME\n\n" + text + "\n\n")
    doku = None
    doku = wiki.getPage(id=f"journals:{date.year}")
    if not doku:
        print(f"  Creating new journal page for {date.year}")
        doku = f"""====== {date.year} ======

"""
    entries = re.findall(
        r"===== (\w+\s\w+) =====\n\n([^=====]*)", doku, re.MULTILINE | re.DOTALL
    )
    annotated_entries = [
        [datetime.strptime(f"{entry[0]} {date.year}", "%B %d %Y"), entry[0], entry[1]]
        for entry in entries
    ]
    final_entries = []
    inserted_new = False
    for entry in annotated_entries:
        entry[2] = entry[2].rstrip()
        entry[2] += "\n\n"
        if not inserted_new:
            if new_entry[0].date() < entry[0].date():
                final_entries.append(new_entry)
                inserted_new = True
            elif new_entry[0].date() == entry[0].date():
                entry[
                    2
                ] += f"""

{new_entry[2]}


"""
                inserted_new = True
        final_entries.append(entry)
    if not inserted_new:
        final_entries.append(new_entry)
        inserted_new = True

    string_entries = [
        f"===== {entry[1]} =====\n\n{entry[2]}" for entry in final_entries
    ]

    new_doku = f"""====== {date.year} ======

{''.join(string_entries)}
"""

    wiki.putPage(id=f"journals:{date.year}", content=new_doku)
    if doku is not None:
        msg.moveToTrash()


@click.group()
@click.pass_context
@click.option(
    "--gmail-secrets-json",
    "gmail_secrets_json",
    type=click.Path(),
    default=GPD.GMAIL_SECRETS_JSON,
    show_default=True,
    help="GMail client secrets file.",
)
@click.option(
    "--gbot-refresh-file",
    "gbot_refresh_file",
    type=click.Path(),
    default=GPD.GBOT_REFRESH_FILE,
    show_default=True,
    help="GBot refresh file (if it exists).",
)
@click.option(
    "--journal-refresh-file",
    "journal_refresh_file",
    type=click.Path(),
    default=GPD.JOURNAL_REFRESH_FILE,
    show_default=True,
    help="Journal refresh file (if it exists).",
)
@click.option(
    "--num-messages",
    "num_messages",
    type=int,
    default=1000,
    show_default=True,
    help="Number of messages to poll for GBot and Journal (each).",
)
@click.option(
    "--wiki-url",
    "wiki_url",
    type=str,
    default=WTD.WIKI_URL,
    show_default=True,
    help="URL of the DokuWiki instance (https).",
)
@click.option(
    "--wiki-secrets-file",
    "wiki_secrets_file",
    type=click.Path(),
    default=WTD.WIKI_SECRETS_FILE,
    show_default=True,
    help="Path to the DokuWiki login secrets JSON file.",
)
@click.option(
    "--task-secrets-file",
    "task_secrets_file",
    type=click.Path(),
    default=TTD.TASK_SECRETS_FILE,
    show_default=True,
    help="Google Tasks client secrets file.",
)
@click.option(
    "--notion-secrets-file",
    "notion_secrets_file",
    type=click.Path(),
    default="~/secrets/notion/secret.json",
    show_default=True,
    help="Notion client secrets file.",
)
@click.option(
    "--task-refresh-token",
    "task_refresh_token",
    type=click.Path(),
    default=TTD.TASK_REFRESH_TOKEN,
    show_default=True,
    help="Google Tasks refresh file (if it exists).",
)
@click.option(
    "--enable-logging",
    "enable_logging",
    type=bool,
    default=False,
    show_default=True,
    help="Whether to enable logging.",
)
@click.option(
    "--headless",
    "headless",
    is_flag=True,
    help="Whether to run in headless (i.e., server) mode.",
)
@click.option(
    "--headless-logdir",
    "headless_logdir",
    type=click.Path(),
    default="~/goromail",
    show_default=True,
    help="Directory in which to store log files for headless mode.",
)
def cli(
    ctx: click.Context,
    gmail_secrets_json,
    gbot_refresh_file,
    journal_refresh_file,
    num_messages,
    wiki_url,
    wiki_secrets_file,
    task_secrets_file,
    notion_secrets_file,
    task_refresh_token,
    enable_logging,
    headless,
    headless_logdir,
):
    """Manage the mail for GBot and Journal."""
    ctx.obj = {
        "enable_logging": enable_logging,
        "gmail_secrets_json": gmail_secrets_json,
        "gbot_refresh_file": gbot_refresh_file,
        "journal_refresh_file": journal_refresh_file,
        "num_messages": num_messages,
        "wiki_url": wiki_url,
        "wiki_secrets_file": wiki_secrets_file,
        "task_secrets_file": task_secrets_file,
        "notion_secrets_file": notion_secrets_file,
        "task_refresh_token": task_refresh_token,
        "headless": headless,
        "headless_logdir": os.path.expanduser(headless_logdir),
    }


@cli.command()
@click.pass_context
@click.option(
    "--categories-csv",
    "categories_csv",
    type=click.Path(),
    default="~/configs/goromail-categories.csv",
    show_default=True,
    help="CSV that maps keywords to wiki pages.",
)
@click.option(
    "--dry-run",
    "dry_run",
    is_flag=True,
    help="Do a dry run; no message deletions.",
)
def bot(ctx: click.Context, categories_csv, dry_run):
    """Process all pending bot commands."""
    if ctx.obj["headless"]:
        Path(ctx.obj["headless_logdir"]).mkdir(parents=True, exist_ok=True)
        logfile = open(os.path.join(ctx.obj["headless_logdir"], "bot.log"), "w")
    else:
        logfile = None
    try:
        gbotCorpus = GBotCorpus(
            "goromal.bot@gmail.com",
            gmail_secrets_json=ctx.obj["gmail_secrets_json"],
            gbot_refresh_file=ctx.obj["gbot_refresh_file"],
            enable_logging=ctx.obj["enable_logging"],
        )
    except Exception as e:
        sys.stderr.write(f"Program error: {e}")
        if logfile is not None:
            logfile.close()
        exit(1)
    try:
        gbot = gbotCorpus.Inbox(ctx.obj["num_messages"])
    except KeyError:
        print(Fore.YELLOW + "Queue empty." + Style.RESET_ALL)
        if logfile is not None:
            logfile.close()
        return
    try:
        with open(os.path.expanduser(ctx.obj["notion_secrets_file"]), "r") as nsf:
            secrets = json.load(nsf)
        notion_api_token = secrets["auth"]
    except:
        sys.stderr.write(f"Failed to load Notion API key")
        if logfile is not None:
            logfile.close()
        exit(1)
    wiki = WikiTools(
        wiki_url=ctx.obj["wiki_url"],
        wiki_secrets_file=ctx.obj["wiki_secrets_file"],
        enable_logging=ctx.obj["enable_logging"],
    )
    try:
        task = TaskManager(
            task_secrets_file=ctx.obj["task_secrets_file"],
            task_refresh_token=ctx.obj["task_refresh_token"],
            enable_logging=ctx.obj["enable_logging"],
        )
    except Exception as e:
        sys.stderr.write(f"Program error: {e}")
        if logfile is not None:
            logfile.close()
        exit(1)
    print(
        Fore.YELLOW
        + f"GBot is processing pending commands{' (DRY RUN)' if dry_run else ''}..."
        + Style.RESET_ALL
    )
    msgs = gbot.fromSenders([TEXT_EMAIL, MAIL_EMAIL]).getMessages()
    try:
        for msg in reversed(msgs):
            text = msg.getText().strip()
            date = msg.getDate()
            matched = False
            if categories_csv is not None:
                with open(os.path.expanduser(categories_csv), "r") as categories:
                    for line in categories:
                        keyword, notion_page_id = (
                            line.split(",")[0],
                            line.split(",")[1].strip(),
                        )
                        matched = process_keyword(
                            text,
                            date.strftime("%m/%d/%Y"),
                            keyword,
                            notion_api_token,
                            notion_page_id,
                            msg,
                            dry_run,
                            logfile,
                        )
                        if matched:
                            break
            if matched:
                continue
            if text.lstrip("-+").isdigit():
                print(f"  Calorie intake on {date}: {text}")
                if logfile is not None:
                    logfile.write("Calories entry\n")
                if not dry_run:
                    caljo_doku = None
                    caljo_doku = wiki.getPage(id="calorie-journal")
                    new_caljo_doku = f"""{caljo_doku}
    * ({date}) {text}"""
                    wiki.putPage(id="calorie-journal", content=new_caljo_doku)
                    if caljo_doku is not None:
                        msg.moveToTrash()
            elif (
                text[:3].lower() == "p0:"
                or text[:3].lower() == "p1:"
                or text[:3].lower() == "p2:"
                or text[:3].lower() == "p3:"
            ):
                print(f"  {text[:2]} task for {date}: {text[3:]}")
                if logfile is not None:
                    logfile.write("Task entry\n")
                if not dry_run:
                    task.putTask(
                        text,
                        f"Generated: {datetime.now().strftime('%m/%d/%Y')}",
                        datetime.today(),
                    )
                    msg.moveToTrash()
            else:
                print(f"  ITNS from {date}: {text}")
                if logfile is not None:
                    logfile.write("Notion:ITNS entry\n")
                if not dry_run:
                    append_text_to_notion_page(
                        notion_api_token, "3ea6f1aa43564b0386bcaba6c7b79870", msg, text
                    )
    except Exception as e:
        sys.stderr.write(f"Program error: {e}")
        if logfile is not None:
            logfile.close()
        exit(1)
    if logfile is not None:
        logfile.close()
    print(Fore.GREEN + f"Done." + Style.RESET_ALL)


@cli.command()
@click.pass_context
@click.option(
    "--dry-run",
    "dry_run",
    is_flag=True,
    help="Do a dry run; no message deletions.",
)
def journal(ctx: click.Context, dry_run):
    """Process all pending journal entries."""
    if ctx.obj["headless"]:
        Path(ctx.obj["headless_logdir"]).mkdir(parents=True, exist_ok=True)
        logfile = open(os.path.join(ctx.obj["headless_logdir"], "journal.log"), "w")
    else:
        logfile = None
    try:
        journalCorpus = JournalCorpus(
            "goromal.journal@gmail.com",
            gmail_secrets_json=ctx.obj["gmail_secrets_json"],
            journal_refresh_file=ctx.obj["journal_refresh_file"],
            enable_logging=ctx.obj["enable_logging"],
        )
    except Exception as e:
        sys.stderr.write(f"Program error: {e}")
        if logfile is not None:
            logfile.close()
        exit(1)
    try:
        journal = journalCorpus.Inbox(ctx.obj["num_messages"])
    except KeyError:
        print(Fore.YELLOW + "Queue empty." + Style.RESET_ALL)
        if logfile is not None:
            logfile.close()
        return
    wiki = WikiTools(
        wiki_url=ctx.obj["wiki_url"],
        wiki_secrets_file=ctx.obj["wiki_secrets_file"],
        enable_logging=ctx.obj["enable_logging"],
    )
    print(
        Fore.YELLOW
        + f"Processing pending journal entries{' (DRY RUN)' if dry_run else ''}..."
        + Style.RESET_ALL
    )
    msgs = journal.fromSenders([TEXT_EMAIL, MAIL_EMAIL]).getMessages()
    for msg in reversed(msgs):
        text = msg.getText()
        date = msg.getDate()
        predate = re.match(r"\d\d?/\d\d?/\d\d\d\d:", text)
        if predate:
            date = datetime.strptime(
                re.match(r"(\d\d?/\d\d?/\d\d\d\d):", text).group(1), "%m/%d/%Y"
            )
            text = text.split(":")[1].strip()
        print(f"  Journal entry for {date}")
        if logfile is not None:
            logfile.write(f"{date}\n")
        if dry_run:
            print(text)
        if not dry_run:
            add_journal_entry_to_wiki(wiki, msg, date, text)
    if logfile is not None:
        logfile.close()
    print(Fore.GREEN + f"Done." + Style.RESET_ALL)


def main():
    cli()


if __name__ == "__main__":
    main()
