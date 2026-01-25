import logging
import click
import sys
import os
import json
import importlib.util
from types import ModuleType
from typing import Callable
import asyncio
from grpc import aio

from easy_google_auth.auth import getGoogleCreds
from gmail_parser.defaults import GmailParserDefaults as GPD
from aapis.tactical.v1 import tactical_pb2_grpc, tactical_pb2

import gspread


def _api_res_from_int(i):
    if i == 1:
        return (
            tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_NO_CREDIT
        )
    elif i == 2:
        return (
            tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_PARTIAL_CREDIT
        )
    elif i == 3:
        return (
            tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_FULL_CREDIT
        )
    else:
        return tactical_pb2.SurveyQuestionResultType.SURVEY_QUESTION_RESULT_TYPE_INVALID


def _load_module_from_path(path: str) -> ModuleType:
    abs_path = os.path.abspath(os.path.expanduser(path))

    if not os.path.isfile(abs_path):
        raise FileNotFoundError(f"Module file not found: {abs_path}")

    module_name = "dynamic_module"
    spec = importlib.util.spec_from_file_location(module_name, abs_path)
    if spec is None or spec.loader is None:
        raise ImportError(f"Unable to create spec for module: {abs_path}")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _get_responses_from_survey(survey):
    def _translate_response_types(response):
        translated_response = []
        for survey_name, survey_date, survey_responses in response:
            translated_response_item_list = []
            for q_name, q_resp in survey_responses:
                translated_response_item_list.append(
                    (q_name, _api_res_from_int(q_resp))
                )
            translated_response.append(
                (survey_name, survey_date, translated_response_item_list)
            )
        return translated_response

    responses = []
    if survey["row_func"] is not None:
        responses = [
            _translate_response_types(survey["row_func"](row)) for row in survey["data"]
        ]
    else:
        print(f"WARNING: could not process survey: {survey['name']}")
    return responses


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
    module_path = config["modules_path"]
    for survey in config["surveys"]:
        sheet = gspread.authorize(
            getGoogleCreds(
                secrets_json,
                refresh_file,
                headless=True,
            )
        ).open_by_key(survey["spreadsheetId"])
        data = sheet.worksheet(survey["sheetName"]).get_all_records()

        row_func = None
        try:
            function_name = survey["funcName"]
            module = _load_module_from_path(module_path)

            if not hasattr(module, function_name):
                raise AttributeError(
                    f"Function '{function_name}' not found in module {module_path}"
                )

            func = getattr(module, function_name)

            if not callable(func):
                raise TypeError(f"'{function_name}' is not callable")

            import inspect

            sig = inspect.signature(func)
            params = [
                p
                for p in sig.parameters.values()
                if p.kind
                not in (inspect.Parameter.VAR_POSITIONAL, inspect.Parameter.VAR_KEYWORD)
            ]
            if len(params) != 1:
                raise ValueError(
                    f"Function '{function_name}' must take exactly one argument"
                )

            row_func = func
        except Exception as e:
            print(
                f"WARNING: unable to import row function for survey {survey['name']}: {e}"
            )

        ctx.obj["surveys"].append(
            {
                "name": survey["name"],
                "sheet": sheet,
                "data": data,
                "row_func": row_func,
            }
        )


@cli.command()
@click.pass_context
def list_results(ctx: click.Context):
    """List outstanding survey results from the cloud"""
    for survey in ctx.obj["surveys"]:
        print(f"Survey: {survey['name']}")
        responses = _get_responses_from_survey(survey)
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
        responses = _get_responses_from_survey(survey)
        for survey_response in responses:
            print(f"  Uploading entry {counter}")
            for subsurvey_response in survey_response:
                survey_name = subsurvey_response[0]
                year, month, day = subsurvey_response[1]
                question_responses = subsurvey_response[2]
                asyncio.run(
                    cmd_impl(port, survey_name, year, month, day, question_responses)
                )
            counter += 1


def main():
    cli()


if __name__ == "__main__":
    main()
