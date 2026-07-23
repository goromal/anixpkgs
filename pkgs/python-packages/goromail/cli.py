import click
import re
import os
import sys
from email import policy
from email.parser import BytesParser
from email.utils import parsedate_to_datetime
from colorama import Fore, Style
from datetime import datetime
from pathlib import Path
import asyncio
from grpc import aio
from gmail_parser.defaults import GmailParserDefaults as GPD
from wiki_tools.wiki import WikiTools
from wiki_tools.defaults import WikiToolsDefaults as WTD
from task_tools.defaults import TaskToolsDefaults as TTD
from notion_tools.manage import NotionTools
from aapis.tactical.v1 import tactical_pb2_grpc, tactical_pb2

MAIL_EMAIL = "andrew.torgesen@gmail.com"
TEXT_EMAIL = "6612105214@vzwpix.com"
MAILDIR_PATH = "/var/mail/goromail"


class PostfixMessage:
    def __init__(self, maildir, key, msg):
        self.key = key
        self.maildir = maildir
        msg = BytesParser(policy=policy.default).parsebytes(msg.as_bytes())
        self.sender = msg["From"]
        self.recipient = msg["To"]
        self.subject = msg["Subject"]
        try:
            self.date = parsedate_to_datetime(msg["Date"]).astimezone()
        except Exception:
            self.date = datetime.now().astimezone()
        plain_parts, html_parts = [], []
        for part in msg.walk():
            if part.get_content_type() == "text/plain":
                plain_parts.append(part.get_content())
            elif part.get_content_type() == "text/html":
                html_parts.append(part.get_content())
        self.raw_text = "\n".join(plain_parts) or "\n".join(html_parts)
        self.text = re.sub(r"<[^>]+>", " ", self.raw_text).strip()

    def getText(self):
        return self.text

    def getDate(self):
        return self.date

    def moveToTrash(self):
        self.maildir.remove(self.key)


def process_keyword(
    text,
    datestr,
    keyword,
    notion,
    notion_page_id,
    msg=None,
    dry_run=False,
    logfile=None,
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
        item = re.sub(r"action:", "⏰", item, flags=re.IGNORECASE)
        if logfile is not None:
            logfile.write(f"Notion:{keyword} entry -> notion.append_blocks\n")
            logfile.flush()
        if not dry_run:
            notion.append_blocks(notion_page_id, item)
            if msg is not None:
                msg.moveToTrash()
        if logfile is not None:
            logfile.write(f"Notion:{keyword} entry done\n")
            logfile.flush()
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
            logfile.write(f"Notion:{keyword} sort entry -> notion.append_blocks\n")
            logfile.flush()
        if not dry_run:
            notion.append_blocks(notion_page_id, item)
            if msg is not None:
                msg.moveToTrash()
        if logfile is not None:
            logfile.write(f"Notion:{keyword} sort entry done\n")
            logfile.flush()
        return True
    return False


def add_journal_entry_to_wiki(wiki, msg, date, text):
    new_entry = (date, date.strftime("%B %d"), "\n\n" + text + "\n\n")
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


def report_journal_entry_to_tactical(tactical_port, date):
    async def cmd_impl(port, year, month, day):
        async with aio.insecure_channel(f"localhost:{port}") as channel:
            stub = tactical_pb2_grpc.TacticalServiceStub(channel)
            try:
                _ = await stub.SubmitSurveyResult(
                    tactical_pb2.SubmitSurveyResultRequest(
                        result=tactical_pb2.SurveyResult(
                            year=year,
                            month=month,
                            day=day,
                            survey_name="Journaling",
                            results=[
                                tactical_pb2.SurveyQuestionResult(
                                    question_name="Submitted entry",
                                    result=tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_FULL_CREDIT,
                                )
                            ],
                        )
                    )
                )
            except:
                pass

    asyncio.run(cmd_impl(tactical_port, date.year, date.month, date.day))


def parse_loseit_email(raw_text):
    """Return (summary_date, consumed_cal, budget_cal) from a Lose It! HTML email, or None."""
    if "Daily calorie budget" not in raw_text:
        return None
    budget_m = re.search(r"Daily calorie budget</td>\s*<td[^>]*>([\d,]+)</td>", raw_text)
    consumed_m = re.search(r"Food calories consumed</td>\s*<td[^>]*>([\d,]+)</td>", raw_text)
    date_m = re.search(r"Daily Summary for\s+\w+,\s+(\w+)\s+(\d+)", raw_text)
    if not (budget_m and consumed_m and date_m):
        return None
    budget = int(budget_m.group(1).replace(",", ""))
    consumed = int(consumed_m.group(1).replace(",", ""))
    month_str, day_str = date_m.group(1), date_m.group(2)
    try:
        summary_date = datetime.strptime(f"{month_str} {day_str} 2000", "%B %d %Y")
    except ValueError:
        return None
    return summary_date, consumed, budget


def parse_loseit_nutrients(raw_text):
    """Return (fat_g, carb_g, protein_g, fat_pct) from a Lose It! email's
    Nutrient Summary table, or None if the table is absent or incomplete.

    Grams cover only foods that have nutrient data; fat_pct is Fat's reported
    share of tracked calories ("% Calories" column).
    """
    if "Nutrient Summary" not in raw_text:
        return None
    section = raw_text.split("Nutrient Summary", 1)[1]

    def grams(label):
        # A label cell whose text starts with `label` (so "Fat" won't match the
        # "&nbsp;&nbsp; Saturated Fat" cell), then a grams cell like "47g".
        m = re.search(
            r">\s*" + re.escape(label) + r"\s*</td>\s*<td[^>]*>\s*([\d,]+)\s*g\b",
            section,
            re.IGNORECASE,
        )
        return int(m.group(1).replace(",", "")) if m else None

    fat_g = grams("Fat")
    carb_g = grams("Carbohydrates")
    protein_g = grams("Protein")
    if fat_g is None or carb_g is None or protein_g is None:
        return None

    fatpct_m = re.search(
        r">\s*Fat\s*</td>\s*<td[^>]*>\s*[\d,]+\s*g\s*</td>\s*"
        r'<td[^>]*align="right"[^>]*>\s*([\d.]+)\s*%',
        section,
        re.IGNORECASE,
    )
    if fatpct_m is None:
        return None
    return fat_g, carb_g, protein_g, float(fatpct_m.group(1))


def eating_discipline_level(consumed, budget, nutrients):
    """Credit level (2 full / 1 partial / 0 none) for 'Discipline in eating'.

    nutrients is (fat_g, carb_g, protein_g, fat_pct) or None. When >=80% of
    consumed calories are backed by nutrient stats, blend the surplus score with
    a fat-share score; otherwise (or with no nutrients) use surplus alone.
    """
    surplus = consumed - budget
    if surplus <= 0:
        surplus_level = 2
    elif surplus <= 200:
        surplus_level = 1
    else:
        surplus_level = 0

    if nutrients is None or consumed <= 0:
        return surplus_level

    fat_g, carb_g, protein_g, fat_pct = nutrients
    tracked_cal = 9 * fat_g + 4 * carb_g + 4 * protein_g
    if tracked_cal / consumed < 0.80:
        return surplus_level

    if fat_pct <= 30:
        fat_level = 2
    elif fat_pct <= 40:
        fat_level = 1
    else:
        fat_level = 0

    return int((surplus_level + fat_level) / 2 + 0.5)  # round half up


def _credit_enum(level):
    T = tactical_pb2.SurveyQuestionResultType
    return {
        0: T.SURVEY_QUESTION_RESULT_TYPE_NO_CREDIT,
        1: T.SURVEY_QUESTION_RESULT_TYPE_PARTIAL_CREDIT,
        2: T.SURVEY_QUESTION_RESULT_TYPE_FULL_CREDIT,
    }[level]


def report_eating_discipline_to_tactical(tactical_port, date, level):
    result_type = _credit_enum(level)

    async def cmd_impl(port, year, month, day):
        async with aio.insecure_channel(f"localhost:{port}") as channel:
            stub = tactical_pb2_grpc.TacticalServiceStub(channel)
            try:
                _ = await stub.SubmitSurveyResult(
                    tactical_pb2.SubmitSurveyResultRequest(
                        result=tactical_pb2.SurveyResult(
                            year=year,
                            month=month,
                            day=day,
                            survey_name="Heart Care",
                            results=[
                                tactical_pb2.SurveyQuestionResult(
                                    question_name="Discipline in eating",
                                    result=result_type,
                                )
                            ],
                        )
                    )
                )
            except:
                pass

    asyncio.run(cmd_impl(tactical_port, date.year, date.month, date.day))


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
    "--wiki-user",
    "wiki_user",
    type=str,
    default="",
    help="Wiki account username.",
)
@click.option(
    "--wiki-pass",
    "wiki_pass",
    type=str,
    default="",
    help="Wiki account password.",
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
    wiki_user,
    wiki_pass,
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
        "wiki_user": wiki_user,
        "wiki_pass": wiki_pass,
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
    help="CSV that maps keywords to notion pages.",
)
@click.option(
    "--tactical-port",
    "tactical_port",
    type=int,
    default=60060,
    show_default=True,
    help="Tactical server port to hit",
)
@click.option(
    "--dry-run",
    "dry_run",
    is_flag=True,
    help="Do a dry run; no message deletions.",
)
def postfix(ctx: click.Context, categories_csv, tactical_port, dry_run):
    """Process all pending postfix commands."""
    import mailbox
    from task_tools.manage import TaskManager

    if ctx.obj["headless"]:
        Path(ctx.obj["headless_logdir"]).mkdir(parents=True, exist_ok=True)
        logfile = open(os.path.join(ctx.obj["headless_logdir"], "postfix.log"), "w")
    else:
        logfile = None

    def log(msg):
        if logfile is not None:
            logfile.write(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}\n")
            logfile.flush()

    try:
        maildir = mailbox.Maildir(MAILDIR_PATH, factory=None)
    except Exception as e:
        sys.stderr.write(f"Program error: {e}")
        if logfile is not None:
            logfile.close()
        exit(1)
    try:
        msgs = []
        for key, msg in maildir.iteritems():
            msgs.append(PostfixMessage(maildir, key, msg))
    except KeyError:
        print(Fore.YELLOW + "Queue empty." + Style.RESET_ALL)
        if logfile is not None:
            logfile.close()
        return
    try:
        notion = NotionTools.from_file(ctx.obj["notion_secrets_file"])
    except Exception as e:
        sys.stderr.write(f"Failed to load Notion API key")
        if logfile is not None:
            logfile.close()
        exit(1)
    wiki = WikiTools(
        wiki_url=ctx.obj["wiki_url"],
        wiki_user=ctx.obj["wiki_user"],
        wiki_pass=ctx.obj["wiki_pass"],
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
    try:
        for i, msg in enumerate(reversed(msgs)):
            text = msg.getText().strip()
            date = msg.getDate()

            loseit = parse_loseit_email(msg.raw_text)
            if loseit is not None:
                summary_date, consumed, budget = loseit
                summary_date = summary_date.replace(year=date.year)
                nutrients = parse_loseit_nutrients(msg.raw_text)
                level = eating_discipline_level(consumed, budget, nutrients)
                surplus = consumed - budget
                extra = ""
                if nutrients is not None and consumed > 0:
                    fat_g, carb_g, protein_g, fat_pct = nutrients
                    coverage = (9 * fat_g + 4 * carb_g + 4 * protein_g) / consumed
                    extra = f", nutrient coverage {coverage:.0%}, fat {fat_pct:.1f}%"
                print(
                    f"  Lose It! daily summary: {consumed} consumed / {budget} budget "
                    f"({'+' if surplus >= 0 else ''}{surplus} cal){extra} -> level {level}"
                )
                log(f"Lose It! summary for {summary_date.date()}: level {level}{extra}")
                if not dry_run:
                    report_eating_discipline_to_tactical(tactical_port, summary_date, level)
                    msg.moveToTrash()
                continue

            if text[:8].lower() == f"journal:":
                text = text[8:]
                predate = re.match(r"\s*\d\d?/\d\d?/\d\d\d\d:", text)
                if predate:
                    date = datetime.strptime(
                        re.match(r"\s*(\d\d?/\d\d?/\d\d\d\d):", text).group(1),
                        "%m/%d/%Y",
                    )
                    text = text.split(":", 1)[1].strip()
                print(f"  Journal entry for {date}")
                log(f"Journal entry for {date}")
                if dry_run:
                    print(text)
                if not dry_run:
                    add_journal_entry_to_wiki(wiki, msg, date, text)
                    report_journal_entry_to_tactical(tactical_port, date)
                continue

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
                            notion,
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
                log(f"Calorie intake for {date}")
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
                log(f"Task entry for {date}")
                if not dry_run:
                    task.putTask(
                        text,
                        f"Generated: {datetime.now().strftime('%m/%d/%Y')}",
                        datetime.today(),
                    )
                    msg.moveToTrash()
            else:
                truncated = text[:2000] + ("…" if len(text) > 2000 else "")
                print(f"  ITNS from {date}: {truncated}")
                log(f"ITNS entry for {date}")
                if not dry_run:
                    notion.append_blocks("3ea6f1aa43564b0386bcaba6c7b79870", truncated)
                    msg.moveToTrash()
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
    "--categories-csv",
    "categories_csv",
    type=click.Path(),
    default="~/configs/goromail-categories.csv",
    show_default=True,
    help="CSV that maps keywords to notion pages.",
)
@click.option(
    "--dry-run",
    "dry_run",
    is_flag=True,
    help="Do a dry run; no message deletions.",
)
def bot(ctx: click.Context, categories_csv, dry_run):
    """Process all pending bot commands."""
    from gmail_parser.corpus import GBotCorpus
    from task_tools.manage import TaskManager

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
        notion = NotionTools.from_file(ctx.obj["notion_secrets_file"])
    except:
        sys.stderr.write(f"Failed to load Notion API key")
        if logfile is not None:
            logfile.close()
        exit(1)
    wiki = WikiTools(
        wiki_url=ctx.obj["wiki_url"],
        wiki_user=ctx.obj["wiki_user"],
        wiki_pass=ctx.obj["wiki_pass"],
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
                            notion,
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
                    notion.append_blocks("3ea6f1aa43564b0386bcaba6c7b79870", text)
                    msg.moveToTrash()
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
    "--categories-csv",
    "categories_csv",
    type=click.Path(),
    default="~/configs/goromail-categories.csv",
    show_default=True,
    help="CSV that maps keywords to notion pages.",
)
@click.option(
    "--dry-run",
    "dry_run",
    is_flag=True,
    help="Do a dry run; no message deletions.",
)
def itns_nudge(ctx: click.Context, categories_csv, dry_run):
    """Randomly pick an ITNS topic to nudge with an action item."""
    import random

    try:
        notion = NotionTools.from_file(ctx.obj["notion_secrets_file"])
    except:
        sys.stderr.write(f"Failed to load Notion API key")
        exit(1)
    notion_pages = []
    if categories_csv is not None:
        with open(os.path.expanduser(categories_csv), "r") as categories:
            for line in categories:
                keyword, notion_page_id = (
                    line.split(",")[0],
                    line.split(",")[1].strip(),
                )
                notion_pages.append((keyword, notion_page_id))
    chosen_keyword, chosen_page_id = random.choice(notion_pages)
    if not process_keyword(
        text=f"{chosen_keyword}: action: Notice me!",
        datestr=datetime.today().strftime("%m/%d/%Y"),
        keyword=chosen_keyword,
        notion=notion,
        notion_page_id=chosen_page_id,
        dry_run=dry_run,
    ):
        sys.stderr.write(f"Failed to upload nudge to Notion")
        exit(1)


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
    from gmail_parser.corpus import JournalCorpus
    from task_tools.manage import TaskManager

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
        wiki_user=ctx.obj["wiki_user"],
        wiki_pass=ctx.obj["wiki_pass"],
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
            text = text.split(":", 1)[1].strip()
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


@cli.command()
@click.pass_context
@click.option(
    "--categories-csv",
    "categories_csv",
    type=click.Path(),
    default="~/configs/goromail-categories.csv",
    show_default=True,
    help="CSV that maps keywords to notion pages.",
)
@click.option(
    "--dry-run",
    "dry_run",
    is_flag=True,
    help="Do a dry run; don't actually rename the pages.",
)
def annotate_triage_pages(ctx: click.Context, categories_csv, dry_run):
    """Re-title triage pages based on content."""
    if ctx.obj["headless"]:
        Path(ctx.obj["headless_logdir"]).mkdir(parents=True, exist_ok=True)
        logfile = open(os.path.join(ctx.obj["headless_logdir"], "annotate.log"), "w")
    else:
        logfile = None
    try:
        notion = NotionTools.from_file(ctx.obj["notion_secrets_file"])
    except:
        sys.stderr.write(f"Failed to load Notion API key")
        if logfile is not None:
            logfile.close()
        exit(1)
    categories = {}
    keyword = "pre-loop"
    try:
        if categories_csv is not None:
            with open(os.path.expanduser(categories_csv), "r") as categories_file:
                for line in categories_file:
                    keyword, notion_page_id = (
                        line.split(",")[0],
                        line.split(",")[1].strip(),
                    )
                    if notion_page_id not in categories:
                        categories[notion_page_id] = keyword.capitalize()
        print(
            Fore.YELLOW
            + f"Annotating triage pages{' (DRY RUN)' if dry_run else ''}..."
            + Style.RESET_ALL
        )
        for notion_page_id, keyword in categories.items():
            success, bullet_count, action_count = notion.do_counts(
                keyword,
                notion_page_id,
                dry_run,
            )
            if success:
                print(
                    f"  {keyword}: {bullet_count} bullets and {action_count} keywords"
                )
                if logfile is not None:
                    logfile.write(f"{keyword}: [{bullet_count}, {action_count}]\n")
            else:
                print(f"  WARNING: Could not process {keyword}")
    except Exception as e:
        sys.stderr.write(f"Program error: {e}")
        if logfile is not None:
            logfile.write(f"Program error on [{keyword}]\n")
            logfile.close()
        exit(1)
    if logfile is not None:
        logfile.close()
    print(Fore.GREEN + f"Done." + Style.RESET_ALL)


def main():
    cli()


if __name__ == "__main__":
    main()
