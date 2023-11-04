import click
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
    "--dry-run",
    "dry_run",
    is_flag=True,
    help="Do a dry run; no message deletions.",
)
def bot(ctx: click.Context, dry_run):
    """Process all pending bot commands."""
    gbot = GBotCorpus(
        "goromal.bot@gmail.com",
        gmail_secrets_json=ctx.obj["gmail_secrets_json"],
        gbot_refresh_file=ctx.obj["gbot_refresh_file"],
        enable_logging=ctx.obj["enable_logging"]
    ).Inbox(ctx.obj["num_messages"])
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
        text = msg.getText()
        date = msg.getDate()
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
        elif text[:6].lower() == "house:":
            print(f"  House offload item: {text[6:]}")
            if not dry_run:
                append_text_to_wiki_page(wiki, "house", msg, text[6:])
        elif text[:9].lower() == "kathleen:":
            print(f"  Kathleen offload item: {text[9:]}")
            if not dry_run:
                append_text_to_wiki_page(wiki, "kathleen", msg, text[9:])
        elif text[:8].lower() == "grayson:":
            print(f"  Grayson offload item: {text[8:]}")
            if not dry_run:
                append_text_to_wiki_page(wiki, "grayson", msg, text[8:])
        elif text[:9].lower() == "harrison:":
            print(f"  Harrison offload item: {text[9:]}")
            if not dry_run:
                append_text_to_wiki_page(wiki, "harrison", msg, text[9:])
        elif text[:7].lower() == "church:":
            print(f"  Church offload item: {text[7:]}")
            if not dry_run:
                append_text_to_wiki_page(wiki, "church", msg, text[7:])
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
    journal = JournalCorpus(
        "goromal.journal@gmail.com",
        gmail_secrets_json=ctx.obj["gmail_secrets_json"],
        journal_refresh_file=ctx.obj["journal_refresh_file"],
        enable_logging=ctx.obj["enable_logging"]
    ).Inbox(ctx.obj["num_messages"])
    print(Fore.YELLOW + f"Journal processing functionality STILL PENDING." + Style.RESET_ALL)
    # TODO

def main():
    cli()

if __name__ == "__main__":
    main()
