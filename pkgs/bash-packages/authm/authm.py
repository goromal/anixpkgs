import click
import sys
from colorama import Fore, Style
from easy_google_auth.auth    import getGoogleService
from gmail_parser.defaults    import GmailParserDefaults   as GPD
from task_tools.defaults      import TaskToolsDefaults     as TTD
from wiki_tools.defaults      import WikiToolsDefaults     as WTD
from book_notes_sync.defaults import BookNotesSyncDefaults as BNSD

@click.group()
def cli():
    """Manage secrets."""

@cli.command()
@click.option(
    "--headless",
    "headless",
    type=bool,
    default=False,
    show_default=True,
    help="Whether to run in headless mode.",
)
def refresh(headless):
    """Refresh all auth tokens one-by-one."""
    print(Fore.YELLOW + "Refreshing GMail token (personal)..." + Style.RESET_ALL)
    if getGoogleService(
        "gmail",
        "v1",
        GPD.getKwargsOrDefault("gmail_secrets_json"),
        GPD.getKwargsOrDefault("gmail_refresh_file"),
        GPD.getKwargsOrDefault("gmail_corpus_scope"),
        headless=headless
    ) is None:
        sys.stderr.write(f"Refresh of {GPD.getKwargsOrDefault('gmail_refresh_file')} needed.")
        exit(1)
    print(Fore.YELLOW + "Refreshing GMail token (gbot)..." + Style.RESET_ALL)
    if getGoogleService(
        "gmail",
        "v1",
        GPD.getKwargsOrDefault("gmail_secrets_json"),
        GPD.getKwargsOrDefault("gbot_refresh_file"),
        GPD.getKwargsOrDefault("gmail_corpus_scope"),
        headless=headless
    ) is None:
        sys.stderr.write(f"Refresh of {GPD.getKwargsOrDefault('gbot_refresh_file')} needed.")
        exit(1)
    print(Fore.YELLOW + "Refreshing GMail token (journal)..." + Style.RESET_ALL)
    if getGoogleService(
        "gmail",
        "v1",
        GPD.getKwargsOrDefault("gmail_secrets_json"),
        GPD.getKwargsOrDefault("journal_refresh_file"),
        GPD.getKwargsOrDefault("gmail_corpus_scope"),
        headless=headless
    ) is None:
        sys.stderr.write(f"Refresh of {GPD.getKwargsOrDefault('journal_refresh_file')} needed.")
        exit(1)
    print(Fore.YELLOW + "Refreshing Docs token..." + Style.RESET_ALL)
    if getGoogleService(
        "docs",
        "v1",
        BNSD.getKwargsOrDefault("docs_secrets_file"),
        BNSD.getKwargsOrDefault("docs_refresh_token"),
        BNSD.getKwargsOrDefault("docs_scope"),
        headless=headless
    ) is None:
        sys.stderr.write(f"Refresh of {BNSD.getKwargsOrDefault('docs_refresh_token')} needed.")
        exit(1)
    print(Fore.YELLOW + "Refreshing Tasks token..." + Style.RESET_ALL)
    if getGoogleService(
        "tasks",
        "v1",
        TTD.getKwargsOrDefault("task_secrets_file"),
        TTD.getKwargsOrDefault("task_refresh_token"),
        TTD.getKwargsOrDefault("task_scope"),
        headless=headless
    ) is None:
        sys.stderr.write(f"Refresh of {TTD.getKwargsOrDefault('task_refresh_token')} needed.")
        exit(1)
    print(Fore.GREEN + "DONE" + Style.RESET_ALL)

@cli.command()
def validate():
    """Validate the secrets files present on the filesystem."""
    print(Fore.RED + "Not yet implemented!" + Style.RESET_ALL)

def main():
    cli()

if __name__ == "__main__":
    main()
