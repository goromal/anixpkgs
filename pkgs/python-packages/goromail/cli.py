import click
from colorama import Fore, Style
from datetime import datetime
from gmail_parser.corpus import GBotCorpus, JournalCorpus
from gmail_parser.defaults import GmailParserDefaults as GPD
from wiki_tools.wiki import WikiTools
from wiki_tools.defaults import WikiToolsDefaults as WTD
from task_tools.manage import TaskManager
from task_tools.defaults import TaskToolsDefaults as TTD

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
    default=True,
    show_default=True,
    help="Whether to enable logging.",
)
def cli(ctx: click.Context, gmail_secrets_json, gbot_refresh_file, journal_refresh_file, num_messages, wiki_url, wiki_secrets_file, task_secrets_file, task_refresh_token, enable_logging):
    """Manage the mail for GBot and Journal."""
    ctx.obj = {
        "gbot": GBotCorpus("goromal.bot@gmail.com", gmail_secrets_json=gmail_secrets_json, gbot_refresh_file=gbot_refresh_file, enable_logging=enable_logging).Inbox(num_messages),
        "jnal": JournalCorpus("goromal.journal@gmail.com", gmail_secrets_json=gmail_secrets_json, journal_refresh_file=journal_refresh_file, enable_logging=enable_logging).Inbox(num_messages),
        "wiki": WikiTools(wiki_url=wiki_url, wiki_secrets_file=wiki_secrets_file, enable_logging=enable_logging),
        "task": TaskManager(task_secrets_file=task_secrets_file, task_refresh_token=task_refresh_token, enable_logging=enable_logging)
    }

@cli.command()
@click.pass_context
@click.option(
    "--dry-run",
    "dry_run",
    is_flag=True,
    help="Do a dry run; no message deletions.",
)
def process(ctx: click.Context, dry_run):
    """Process all pending commands."""
    print(Fore.YELLOW + f"GBot is processing pending commands{' (DRY RUN)' if dry_run else ''}..." + Style.RESET_ALL)
    msgs = ctx.obj["gbot"].fromSenders(['6612105214@vzwpix.com']).getMessages()
    for msg in reversed(msgs):
        text = msg.getText()
        date = msg.getDate()
        if text.isnumeric():
            print(f"  Calorie intake on {date}: {text}")
            if not dry_run:
                caljo_doku = None
                caljo_doku = ctx.obj["wiki"].getPage(id="calorie-journal")
                new_caljo_doku = f"""{caljo_doku}
  * ({date}) {text}"""
                ctx.obj["wiki"].putPage(id="calorie-journal", content=new_caljo_doku)
                if caljo_doku is not None:
                    msg.moveToTrash()
        elif text[:9].lower() == "remind me":
            print(f"  Reminder from {date}: {text}")
            if not dry_run:
                ctx.obj["task"].putTask(text, "", datetime.today())
                msg.moveToTrash()
        else:
            print(f"  ITNS from {date}: {text}")
            if not dry_run:
                itns_doku = None
                itns_doku = ctx.obj["wiki"].getPage(id="itns")
                new_itns_doku = f"""{itns_doku}
                
----

{text}
"""
                ctx.obj["wiki"].putPage(id="itns", content=new_itns_doku)
                if itns_doku is not None:
                    msg.moveToTrash()
    print(Fore.YELLOW + f"Journal processing functionality STILL PENDING." + Style.RESET_ALL)
    # TODO
    print(Fore.GREEN + f"Done." + Style.RESET_ALL)
    

def main():
    cli()

if __name__ == "__main__":
    main()
