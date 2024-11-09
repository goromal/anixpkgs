import click
import sys
from colorama import Fore, Style
from easy_google_auth.auth import getGoogleService, CredentialsRefreshException
from gmail_parser.defaults import GmailParserDefaults as GPD


@click.group()
def cli():
    """Manage secrets."""


@cli.command()
@click.option(
    "--headless",
    "headless",
    is_flag=True,
    help="Run in headless mode.",
)
@click.option(
    "--force",
    "force",
    is_flag=True,
    help="Force the auth files to be re-written.",
)
def refresh(headless, force):
    """Refresh all auth tokens one-by-one."""
    print(Fore.YELLOW + "Refreshing Personal Tokens..." + Style.RESET_ALL)
    try:
        getGoogleService(
            "gmail",
            "v1",
            GPD.getKwargsOrDefault("gmail_secrets_json"),
            GPD.getKwargsOrDefault("gmail_refresh_file"),
            headless=headless,
            force=force,
        )
    except CredentialsRefreshException:
        sys.stderr.write(
            f"Refresh of {GPD.getKwargsOrDefault('gmail_refresh_file')} needed."
        )
        exit(1)
    print(Fore.YELLOW + "Refreshing Bot Tokens..." + Style.RESET_ALL)
    try:
        getGoogleService(
            "gmail",
            "v1",
            GPD.getKwargsOrDefault("gmail_secrets_json"),
            GPD.getKwargsOrDefault("gbot_refresh_file"),
            headless=headless,
            force=force,
        )
    except CredentialsRefreshException:
        sys.stderr.write(
            f"Refresh of {GPD.getKwargsOrDefault('gbot_refresh_file')} needed."
        )
        exit(1)
    print(Fore.YELLOW + "Refreshing Journal Tokens..." + Style.RESET_ALL)
    try:
        getGoogleService(
            "gmail",
            "v1",
            GPD.getKwargsOrDefault("gmail_secrets_json"),
            GPD.getKwargsOrDefault("journal_refresh_file"),
            headless=headless,
            force=force,
        )
    except CredentialsRefreshException:
        sys.stderr.write(
            f"Refresh of {GPD.getKwargsOrDefault('journal_refresh_file')} needed."
        )
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
