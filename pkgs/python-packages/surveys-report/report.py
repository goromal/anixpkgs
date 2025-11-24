import logging
import click
import sys
import os
import json
from datetime import datetime
import asyncio
from grpc import aio

from easy_google_auth.auth import getGoogleCreds
from gmail_parser.defaults import GmailParserDefaults as GPD
from aapis.tactical.v1 import tactical_pb2_grpc, tactical_pb2

import gspread


def process_daily_log(row):
    def get_date(row):
        day_str = row.get("What day is this for?", "").strip()
        if day_str:
            dt = datetime.strptime(day_str, "%m/%d/%Y")
        else:
            ts = row["Timestamp"]
            dt = datetime.strptime(ts, "%m/%d/%Y %H:%M:%S")

        return dt.year, dt.month, dt.day

    def get_brush_teeth(row):
        ans = row["Did you brush your teeth?"]
        if "morning" in ans.lower() and "evening" in ans.lower():
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_FULL_CREDIT
            )
        elif "morning" in ans.lower() or "evening" in ans.lower():
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_PARTIAL_CREDIT
            )
        else:
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_NO_CREDIT
            )

    def get_back_pain(row):
        ans = row["Did you have back stiffness or pain today?"]
        if ans == "":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_INVALID
            )
        elif "None" in ans:
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_FULL_CREDIT
            )
        else:
            n = len(ans.split(","))
            if n == 1:
                return (
                    tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_PARTIAL_CREDIT
                )
            else:
                return (
                    tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_NO_CREDIT
                )

    def get_back_care(row):
        ans = row["Did you do back exercises today?"]
        if ans == "":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_INVALID
            )
        elif ans == "No":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_NO_CREDIT
            )
        else:
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_FULL_CREDIT
            )

    def get_sick(row):
        ans = row["Did you feel sick at all today?"]
        if ans == "":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_INVALID
            )
        elif ans == "Yes":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_NO_CREDIT
            )
        else:
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_FULL_CREDIT
            )

    def get_do_it(row):
        ans = row["Did you do it?"]
        if ans == "":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_INVALID
            )
        elif ans == "No":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_INVALID
            )
        else:
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_FULL_CREDIT
            )

    def get_not_do_it(row):
        ans = row["Did you not do it?"]
        if ans == "":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_INVALID
            )
        elif ans == "No":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_NO_CREDIT
            )
        else:
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_FULL_CREDIT
            )

    def get_disciplined_eating(row):
        ans1 = row["Were you disciplined in how much you ate today?"]
        ans2 = row["Were you mindful of the content of the food you ate today?"]
        if ans1 == "":
            if ans2 == "":
                return (
                    tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_INVALID
                )
            elif ans2 == "Yes":
                return (
                    tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_PARTIAL_CREDIT
                )
            else:
                return (
                    tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_NO_CREDIT
                )
        if ans1 == "Yes":
            if ans2 == "" or ans2 == "No":
                return (
                    tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_PARTIAL_CREDIT
                )
            else:
                return (
                    tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_FULL_CREDIT
                )
        else:
            if ans2 == "":
                return (
                    tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_NO_CREDIT
                )
            elif ans2 == "Yes":
                return (
                    tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_PARTIAL_CREDIT
                )
            else:
                return (
                    tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_NO_CREDIT
                )

    def get_motivation(row):
        ans = row[
            "Did you feel exhausted and/or without motivation at any point today?"
        ]
        if ans == "":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_INVALID
            )
        elif ans == "Yes":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_NO_CREDIT
            )
        else:
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_FULL_CREDIT
            )

    def get_fight(row):
        ans1 = row["Did you get in a fight today?"]
        ans2 = row[
            "If you were firm today, were you at least discrete AND actually helpful?"
        ]
        if ans1 == "":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_INVALID
            )
        elif ans1 == "Big one":
            if ans2 == "Yes":
                return (
                    tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_PARTIAL_CREDIT
                )
            else:
                return (
                    tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_NO_CREDIT
                )
        elif ans1 == "Small one":
            if ans2 == "Yes":
                return (
                    tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_FULL_CREDIT
                )
            else:
                return (
                    tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_PARTIAL_CREDIT
                )
        else:
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_FULL_CREDIT
            )

    def get_kids(row):
        ans = row["Did you lose your temper with the kids today?"]
        if ans == "":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_INVALID
            )
        elif ans == "Nope":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_FULL_CREDIT
            )
        elif ans == "A little":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_PARTIAL_CREDIT
            )
        else:
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_NO_CREDIT
            )

    def get_proud(row):
        ans = row["Are you proud of today?"]
        if ans == "":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_INVALID
            )
        elif ans == "Yes":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_FULL_CREDIT
            )
        elif ans == "Kind of":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_PARTIAL_CREDIT
            )
        else:
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_NO_CREDIT
            )

    def get_floss(row):
        ans = row["Did you floss?"]
        if ans == "":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_INVALID
            )
        elif ans == "Yes":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_FULL_CREDIT
            )
        else:
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_NO_CREDIT
            )

    def get_skin_care(row):
        ans = row["Did you take care of your skin?"]
        if ans == "":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_INVALID
            )
        elif ans == "Yes":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_FULL_CREDIT
            )
        elif ans == "Sort Of":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_PARTIAL_CREDIT
            )
        else:
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_NO_CREDIT
            )

    def get_stronger(row):
        ans = row["Did you do something to get stronger today?"]
        if ans == "":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_INVALID
            )
        elif ans == "Yes":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_FULL_CREDIT
            )
        else:
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_NO_CREDIT
            )

    def get_sleep(row):
        ans = row["Did you sleep >= 7 hours last night?"]
        if ans == "":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_INVALID
            )
        elif ans == "Yes":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_FULL_CREDIT
            )
        else:
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_NO_CREDIT
            )

    def get_headache(row):
        ans = row["Did you have a headache today?"]
        if ans == "":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_INVALID
            )
        elif ans == "Yes":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_NO_CREDIT
            )
        else:
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_FULL_CREDIT
            )

    def get_laptop(row):
        ans = row["Did you go on your laptop tonight?"]
        if ans == "":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_INVALID
            )
        elif ans == "Yes":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_PARTIAL_CREDIT
            )
        else:
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_FULL_CREDIT
            )

    def get_artistic(row):
        ans = row["Did you do something artistic today?"]
        if ans == "":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_INVALID
            )
        elif ans == "Yes":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_FULL_CREDIT
            )
        else:
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_NO_CREDIT
            )

    def get_spiritual(row):
        ans = row["Did you ponder something spiritual today?"]
        if ans == "":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_INVALID
            )
        elif ans == "Yes":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_FULL_CREDIT
            )
        else:
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_NO_CREDIT
            )

    def get_pray(row):
        ans = row["Did you pray on your own today?"]
        if ans == "":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_INVALID
            )
        elif ans == "Yes":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_FULL_CREDIT
            )
        else:
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_NO_CREDIT
            )

    def get_mouth_care(row):
        ans1 = row["Did you use mouthwash?"]
        ans2 = row["Did you use a waterpik?"]
        if ans1 == "" and ans2 == "":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_INVALID
            )
        elif ans1 == "Yes" and ans2 == "Yes":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_FULL_CREDIT
            )
        elif ans1 == "Yes" or ans2 == "Yes":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_PARTIAL_CREDIT
            )
        else:
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_NO_CREDIT
            )

    def get_prioritization(row):
        ans = row[
            "Did you prioritize life management practices before your body lost motivation?"
        ]
        if ans == "":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_INVALID
            )
        elif ans == "Yes":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_FULL_CREDIT
            )
        else:
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_NO_CREDIT
            )

    def get_statin(row):
        ans = row["Did you take your statin?"]
        if ans == "":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_INVALID
            )
        elif ans == "Yes":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_FULL_CREDIT
            )
        else:
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_NO_CREDIT
            )

    def get_presence(row):
        ans = row["Were you present today?"]
        if ans == "":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_INVALID
            )
        score = 0
        if "Yes (Y)" in ans:
            score += 1
        if "Yes (K)" in ans:
            score += 2
        if "No (Y)" in ans:
            score -= 1
        if "No (K)" in ans:
            score -= 2
        if score < 0:
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_NO_CREDIT
            )
        elif score > 0:
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_FULL_CREDIT
            )
        else:
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_PARTIAL_CREDIT
            )

    def get_soda(row):
        ans = row["How was your water : soda ratio today?"]
        if ans == "":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_INVALID
            )
        elif ans == "High":
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_FULL_CREDIT
            )
        else:
            return (
                tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_NO_CREDIT
            )

    return [
        (
            "Heart Care",
            get_date(row),
            [
                ("Discipline in eating", get_disciplined_eating(row)),
                ("Statin usage", get_statin(row)),
                ("Strength training", get_stronger(row)),
            ],
        ),
        (
            "Mouth Care",
            get_date(row),
            [
                ("Brushing teeth", get_brush_teeth(row)),
                ("Flossing", get_floss(row)),
                ("Auxiliary care", get_mouth_care(row)),
            ],
        ),
        (
            "Back Care",
            get_date(row),
            [("Back pain", get_back_pain(row)), ("Back exercises", get_back_care(row))],
        ),
        (
            "Misc. Care",
            get_date(row),
            [
                ("Adequate sleep", get_sleep(row)),
                ("Avoid headaches", get_headache(row)),
                ("Limit soda", get_soda(row)),
                ("Skin care", get_skin_care(row)),
                ("Avoiding illness", get_sick(row)),
            ],
        ),
        (
            "Discipline",
            get_date(row),
            [
                ("Do it", get_do_it(row)),
                ("Don't do it", get_not_do_it(row)),
                ("Avoiding lethargy", get_motivation(row)),
                ("Prioritizing important things", get_prioritization(row)),
            ],
        ),
        (
            "Interpersonal Skills",
            get_date(row),
            [("Fighting right", get_fight(row)), ("Patience with kids", get_kids(row))],
        ),
        (
            "Well-Roundedness",
            get_date(row),
            [
                ("Avoiding laptop monopoly", get_laptop(row)),
                ("Artistic development", get_artistic(row)),
            ],
        ),
        (
            "Presence and Reflection",
            get_date(row),
            [
                ("Presence", get_presence(row)),
                ("Spiritual reflection", get_spiritual(row)),
                ("Prayer", get_pray(row)),
                ("Pride in my day", get_proud(row)),
            ],
        ),
    ]


@click.group()
@click.pass_context
@click.option(
    "--secrets-json",
    "secrets_json",
    type=click.Path(),
    default=GPD.GMAIL_SECRETS_JSON,
    show_default=True,
    help="Client secrets file.",
)
@click.option(
    "--refresh-file",
    "refresh_file",
    type=click.Path(),
    default=GPD.GMAIL_REFRESH_FILE,
    show_default=True,
    help="Refresh file (if it exists).",
)
@click.option(
    "--config-json",
    "config_json",
    type=click.Path(),
    default="~/configs/survey-results.json",
    show_default=True,
    help="Survey results config file.",
)
@click.option(
    "--enable-logging",
    "enable_logging",
    type=bool,
    default=GPD.ENABLE_LOGGING,
    show_default=True,
    help="Whether to enable logging.",
)
def cli(ctx: click.Context, secrets_json, refresh_file, config_json, enable_logging):
    """Survey results analysis tool."""
    secrets_json = os.path.expanduser(secrets_json)
    refresh_file = os.path.expanduser(refresh_file)
    config_json = os.path.expanduser(config_json)
    with open(config_json, "r") as configfile:
        config = json.load(configfile)
    if enable_logging:
        logging.getLogger().addHandler(logging.StreamHandler(sys.stdout))
    ctx.obj = {"config": config, "surveys": []}
    for survey in config["surveys"]:
        sheet = gspread.authorize(
            getGoogleCreds(
                secrets_json,
                refresh_file,
                headless=True,
            )
        ).open_by_key(survey["spreadsheetId"])
        data = sheet.worksheet(survey["sheetName"]).get_all_records()
        ctx.obj["surveys"].append(
            {
                "name": survey["name"],
                "sheet": sheet,
                "data": data,
            }
        )


@cli.command()
@click.pass_context
def list_results(ctx: click.Context):
    """List outstanding survey results from the cloud"""
    for survey in ctx.obj["surveys"]:
        print(f"Survey: {survey['name']}")
        if survey["name"] == "Daily Log":
            responses = [process_daily_log(row) for row in survey["data"]]
        else:
            responses = ["UNSUPPORTED SURVEY"]
        for response in responses:
            print(f"    {response}")
            print()


@cli.command()
@click.pass_context
@click.option(
    "--port",
    "port",
    type=int,
    default=60060,
    show_default=True,
    help="Server port to hit",
)
def upload_results(ctx: click.Context, port):
    """Upload survey results to a tactical server"""

    async def cmd_impl(port, survey_name, year, month, day, question_responses):
        async with aio.insecure_channel(f"localhost:{port}") as channel:
            stub = tactical_pb2_grpc.TacticalServiceStub(channel)
            try:
                response = await stub.SubmitSurveyResult(
                    tactical_pb2.SubmitSurveyResultRequest(
                        result=tactical_pb2.SurveyResult(
                            year=year,
                            month=month,
                            day=day,
                            survey_name=survey_name,
                            results=[
                                tactical_pb2.SurveyQuestionResult(
                                    question_name=qr[0], result=qr[1]
                                )
                                for qr in question_responses
                            ],
                        )
                    )
                )
            except:
                print(
                    f"tacticald either is not running or is not listening on port {port}"
                )
                exit()
        if not response.success:
            print("FAILED")

    counter = 1
    for survey in ctx.obj["surveys"]:
        print(f"Survey: {survey['name']}")
        if survey["name"] == "Daily Log":
            responses = [process_daily_log(row) for row in survey["data"]]
            for survey_response in responses:
                print(f"  Uploading entry {counter}")
                for subsurvey_response in survey_response:
                    survey_name = subsurvey_response[0]
                    year, month, day = subsurvey_response[1]
                    question_responses = subsurvey_response[2]
                    # print(f"    Survey map: {survey_name}")
                    asyncio.run(
                        cmd_impl(
                            port, survey_name, year, month, day, question_responses
                        )
                    )
                counter += 1


def main():
    cli()


if __name__ == "__main__":
    main()
