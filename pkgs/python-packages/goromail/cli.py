import click
import re
import os
from colorama import Fore, Style
from datetime import datetime
from gmail_parser.corpus import GBotCorpus, JournalCorpus
from gmail_parser.defaults import GmailParserDefaults as GPD
from wiki_tools.wiki import WikiTools
from wiki_tools.defaults import WikiToolsDefaults as WTD
from task_tools.manage import TaskManager
from task_tools.defaults import TaskToolsDefaults as TTD

def append_text_to_wiki_page(wiki, id, msg, text):
    doku = None
    doku = wiki.getPage(id=id)
    new_doku = f"""{doku}

---- 

{text}
"""
    wiki.putPage(id=id, content=new_doku)
    if doku is not None:
        msg.moveToTrash()

def process_keyword(text, datestr, keyword, page_id, wiki, msg, dry_run):
    n = len(keyword)
    if text[:(n+1)].lower() == f"{keyword}:":
        matter = text[(n+1):].strip()
        print(f"  {keyword} offload item: {matter}")
        if matter[:3].lower() == "p0:":
            item = f"[::::{datestr}::::] {matter[3:].strip()}"
        elif matter[:3].lower() == "p1:":
            item = f"[:::{datestr}:::] {matter[3:].strip()}"
        else:
            item = f"[**{datestr}**] {matter.strip()}"
        if not dry_run:
            append_text_to_wiki_page(wiki, page_id, msg, item)
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
    entries = re.findall(r"===== (\w+\s\w+) =====\n\n([^=====]*)", doku, re.MULTILINE | re.DOTALL)
    annotated_entries = [[datetime.strptime(f"{entry[0]} {date.year}", "%B %d %Y"), entry[0], entry[1]] for entry in entries]
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
                entry[2] += f"""

{new_entry[2]}


"""
                inserted_new = True
        final_entries.append(entry)
    if not inserted_new:
        final_entries.append(new_entry)
        inserted_new = True

    string_entries = [f"===== {entry[1]} =====\n\n{entry[2]}" for entry in final_entries]

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
    type=click.Path(exists=True),
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
    type=click.Path(exists=True),
    default=WTD.WIKI_SECRETS_FILE,
    show_default=True,
    help="Path to the DokuWiki login secrets JSON file.",
)
@click.option(
    "--task-secrets-file",
    "task_secrets_file",
    type=click.Path(exists=True),
    default=TTD.TASK_SECRETS_FILE,
    show_default=True,
    help="Google Tasks client secrets file.",
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
def cli(ctx: click.Context, gmail_secrets_json, gbot_refresh_file, journal_refresh_file, num_messages, wiki_url, wiki_secrets_file, task_secrets_file, task_refresh_token, enable_logging):
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
        "task_refresh_token": task_refresh_token
    }

@cli.command()
@click.pass_context
@click.option(
    "--categories-csv",
    "categories_csv",
    type=click.Path(exists=True),
    default=os.path.expanduser("~/configs/goromail-categories.csv"),
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
    try:
        gbot = GBotCorpus(
            "goromal.bot@gmail.com",
            gmail_secrets_json=ctx.obj["gmail_secrets_json"],
            gbot_refresh_file=ctx.obj["gbot_refresh_file"],
            enable_logging=ctx.obj["enable_logging"]
        ).Inbox(ctx.obj["num_messages"])
    except KeyError:
        print(Fore.YELLOW + "Queue empty." + Style.RESET_ALL)
    wiki = WikiTools(
        wiki_url=ctx.obj["wiki_url"],
        wiki_secrets_file=ctx.obj["wiki_secrets_file"],
        enable_logging=ctx.obj["enable_logging"]
    )
    task = TaskManager(
        task_secrets_file=ctx.obj["task_secrets_file"],
        task_refresh_token=ctx.obj["task_refresh_token"],
        enable_logging=ctx.obj["enable_logging"]
    )
    print(Fore.YELLOW + f"GBot is processing pending commands{' (DRY RUN)' if dry_run else ''}..." + Style.RESET_ALL)
    msgs = gbot.fromSenders(['6612105214@vzwpix.com']).getMessages()
    for msg in reversed(msgs):
        text = msg.getText().strip()
        date = msg.getDate()
        matched = False
        if categories_csv is not None:
            with open(categories_csv, "r") as categories:
                for line in categories:
                    keyword, page_id = line.split(",")[0], line.split(",")[1]
                    matched = process_keyword(text, date.strftime('%m/%d/%Y'), keyword, page_id, wiki, msg, dry_run)
                    if matched:
                        break
        if matched:
            continue
        if text.isnumeric():
            print(f"  Calorie intake on {date}: {text}")
            if not dry_run:
                caljo_doku = None
                caljo_doku = wiki.getPage(id="calorie-journal")
                new_caljo_doku = f"""{caljo_doku}
  * ({date}) {text}"""
                wiki.putPage(id="calorie-journal", content=new_caljo_doku)
                if caljo_doku is not None:
                    msg.moveToTrash()
        elif text[:3].lower() == "p0:" or text[:3].lower() == "p1:" or text[:3].lower() == "p2:" or text[:3].lower() == "p3:":
            print(f"  {text[:2]} task for {date}: {text[3:]}")
            if not dry_run:
                task.putTask(text, f"Generated: {datetime.now().strftime('%m/%d/%Y')}", datetime.today())
                msg.moveToTrash()
        else:
            print(f"  ITNS from {date}: {text}")
            if not dry_run:
                append_text_to_wiki_page(wiki, "itns", msg, text)
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
    try:
        journal = JournalCorpus(
            "goromal.journal@gmail.com",
            gmail_secrets_json=ctx.obj["gmail_secrets_json"],
            journal_refresh_file=ctx.obj["journal_refresh_file"],
            enable_logging=ctx.obj["enable_logging"]
        ).Inbox(ctx.obj["num_messages"])
    except KeyError:
        print(Fore.YELLOW + "Queue empty." + Style.RESET_ALL)
    wiki = WikiTools(
        wiki_url=ctx.obj["wiki_url"],
        wiki_secrets_file=ctx.obj["wiki_secrets_file"],
        enable_logging=ctx.obj["enable_logging"]
    )
    print(Fore.YELLOW + f"Processing pending journal entries{' (DRY RUN)' if dry_run else ''}..." + Style.RESET_ALL)
    msgs = journal.fromSenders(['6612105214@vzwpix.com']).getMessages()
    for msg in reversed(msgs):
        text = msg.getText()
        date = msg.getDate()
        print(f"  Journal entry for {date}")
        if not dry_run:
            add_journal_entry_to_wiki(wiki, msg, date, text)
    print(Fore.GREEN + f"Done." + Style.RESET_ALL)

def main():
    cli()

if __name__ == "__main__":
    main()
