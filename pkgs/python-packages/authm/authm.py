import click
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
def refresh():
    """Refresh all auth tokens one-by-one."""
    print(Fore.YELLOW + "Refreshing GMail token #1..." + Style.RESET_ALL)
    _ = getGoogleService(
        "gmail",
        "v1",
        GPD.getKwargsOrDefault("gmail_secrets_json"),
        GPD.getKwargsOrDefault("gmail_refresh_file"),
        GPD.getKwargsOrDefault("gmail_corpus_scope")
    )
    print(Fore.YELLOW + "Refreshing GMail token #2..." + Style.RESET_ALL)
    _ = 0 # TODO
    print(Fore.YELLOW + "Refreshing Docs token..." + Style.RESET_ALL)
    _ = getGoogleService(
        "docs",
        "v1",
        BNSD.getKwargsOrDefault("docs_secrets_file"),
        BNSD.getKwargsOrDefault("docs_refresh_token"),
        BNSD.getKwargsOrDefault("docs_scope")
    )
    print(Fore.YELLOW + "Refreshing Tasks token..." + Style.RESET_ALL)
    _ = getGoogleService(
        "tasks",
        "v1",
        TTD.getKwargsOrDefault("task_secrets_file"),
        TTD.getKwargsOrDefault("task_refresh_token"),
        TTD.getKwargsOrDefault("task_scope")
    )
    print(Fore.GREEN + "DONE" + Style.RESET_ALL)

@cli.command()
def validate():
    """Validate the secrets files present on the filesystem."""
    print(Fore.RED + "Not yet implemented!" + Style.RESET_ALL)

def main():
    cli()

if __name__ == "__main__":
    main()