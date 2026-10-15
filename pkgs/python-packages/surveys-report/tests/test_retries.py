import gspread
import pytest
import requests

from surveys_report.cli import _MAX_ATTEMPTS, _with_retries


def _api_error(status_code, body=None):
    """Build the APIError gspread raises for a given HTTP response."""
    response = requests.Response()
    response.status_code = status_code
    if body is None:
        body = (
            '{"error": {"code": %d, "message": "boom", "status": "ERROR"}}'
            % status_code
        )
    response._content = body.encode()
    return gspread.exceptions.APIError(response)


class _Flaky:
    """Callable that raises `err` for the first `failures` calls, then succeeds."""

    def __init__(self, failures, err):
        self.failures = failures
        self.err = err
        self.calls = 0

    def __call__(self):
        self.calls += 1
        if self.calls <= self.failures:
            raise self.err
        return "sheet"


@pytest.fixture(autouse=True)
def no_sleeping(monkeypatch):
    """Keep the backoff from actually sleeping during tests."""
    slept = []
    monkeypatch.setattr("surveys_report.cli.time.sleep", slept.append)
    return slept


def test_retries_transient_error_until_it_succeeds(no_sleeping):
    flaky = _Flaky(2, _api_error(503))

    assert _with_retries("open sheet", flaky) == "sheet"

    assert flaky.calls == 3
    assert no_sleeping == [2, 4]


def test_returns_immediately_when_the_call_succeeds(no_sleeping):
    assert _with_retries("open sheet", _Flaky(0, _api_error(503))) == "sheet"
    assert no_sleeping == []


@pytest.mark.parametrize("status_code", [408, 429, 500, 502, 503, 504])
def test_transient_status_codes_are_retried(status_code, no_sleeping):
    flaky = _Flaky(1, _api_error(status_code))

    assert _with_retries("open sheet", flaky) == "sheet"

    assert flaky.calls == 2


@pytest.mark.parametrize("status_code", [400, 403, 404])
def test_permanent_status_codes_are_raised_without_retrying(status_code, no_sleeping):
    flaky = _Flaky(1, _api_error(status_code))

    with pytest.raises(gspread.exceptions.APIError):
        _with_retries("open sheet", flaky)

    assert flaky.calls == 1
    assert no_sleeping == []


def test_gives_up_after_max_attempts_and_reraises(no_sleeping):
    flaky = _Flaky(_MAX_ATTEMPTS, _api_error(503))

    with pytest.raises(gspread.exceptions.APIError):
        _with_retries("open sheet", flaky)

    assert flaky.calls == _MAX_ATTEMPTS
    # Bounded backoff: it must not sleep after the final attempt.
    assert len(no_sleeping) == _MAX_ATTEMPTS - 1


def test_non_json_error_body_falls_back_to_the_http_status(no_sleeping):
    # Google's 5xx responses are frequently HTML, which makes gspread report
    # code -1; the HTTP status is what tells us the failure is transient.
    err = _api_error(503, body="<html>Service Unavailable</html>")
    assert err.code == -1
    flaky = _Flaky(1, err)

    assert _with_retries("open sheet", flaky) == "sheet"

    assert flaky.calls == 2
