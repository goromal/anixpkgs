import json
import os
import stat
import sys
import time

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from anix_upgrade_ui import create_app


def make_fake_bin(tmp_path, script):
    path = tmp_path / "fake-upgrade"
    path.write_text("#!/bin/sh\n" + script + "\n")
    path.chmod(path.stat().st_mode | stat.S_IXUSR)
    return str(path)


def make_client(tmp_path, script="echo done"):
    app = create_app(
        subdomain="",
        upgrade_bin=make_fake_bin(tmp_path, script),
        state_dir=str(tmp_path / "state"),
    )
    return app.test_client()


def wait_status(client, want, timeout=10.0):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        data = client.get("/status").get_json()
        if data["status"] == want:
            return data
        time.sleep(0.05)
    pytest.fail(f"status never became {want}")


def test_index_returns_200(tmp_path):
    assert make_client(tmp_path).get("/").status_code == 200


def test_status_idle_initially(tmp_path):
    data = make_client(tmp_path).get("/status").get_json()
    assert data["running"] is False
    assert data["status"] == "idle"


def test_run_returns_202_then_success(tmp_path):
    client = make_client(tmp_path)
    resp = client.post("/run", data={})
    assert resp.status_code == 202
    body = resp.get_json()
    assert body["started"] is True
    assert body["run_id"] is not None
    data = wait_status(client, "success")
    assert data["running"] is False


def test_run_while_running_returns_409(tmp_path):
    client = make_client(tmp_path, script="sleep 5")
    assert client.post("/run", data={}).status_code == 202
    assert client.post("/run", data={}).status_code == 409
    # cleanup: kill the sleeper
    state_file = tmp_path / "state" / "state.json"
    os.kill(json.loads(state_file.read_text())["pid"], 15)
    wait_status(client, "failed")


def test_run_passes_branch_and_flags(tmp_path):
    client = make_client(tmp_path, script='echo "ARGS:$@"')
    client.post("/run", data={"branch": "dev/foo", "local": "1", "boot": "1"})
    wait_status(client, "success")
    log = (tmp_path / "state" / "current.log").read_text()
    assert "ARGS:-b dev/foo --local --boot" in log


def test_run_version_takes_precedence_over_branch(tmp_path):
    client = make_client(tmp_path, script='echo "ARGS:$@"')
    client.post("/run", data={"version": "8.1.0", "branch": "dev/foo"})
    wait_status(client, "success")
    log = (tmp_path / "state" / "current.log").read_text()
    assert "ARGS:-v 8.1.0" in log
    assert "dev/foo" not in log


def test_stream_serves_finished_run(tmp_path):
    client = make_client(tmp_path, script="echo hello")
    client.post("/run", data={})
    wait_status(client, "success")
    resp = client.get("/stream")
    assert resp.content_type.startswith("text/event-stream")
    assert resp.headers["X-Accel-Buffering"] == "no"
    body = resp.get_data(as_text=True)
    assert "data: hello" in body
    assert "data: [UPGRADE SUCCESSFUL]" in body
    assert body.rstrip().endswith("data: [DONE]")


def test_log_download_no_run(tmp_path):
    resp = make_client(tmp_path).get("/log")
    assert resp.status_code == 200
    assert b"No log available" in resp.data


def test_log_download_after_run(tmp_path):
    client = make_client(tmp_path, script="echo hello-from-run")
    client.post("/run", data={})
    wait_status(client, "success")
    resp = client.get("/log")
    assert resp.status_code == 200
    assert b"hello-from-run" in resp.data


def test_list_dirs_works(tmp_path):
    client = make_client(tmp_path)
    (tmp_path / "subdir").mkdir()
    resp = client.post("/api/list-dirs", json={"path": str(tmp_path)})
    assert resp.status_code == 200
    assert "subdir" in resp.get_json()["dirs"]


# ── REST API (v1) ────────────────────────────────────────────────────────────

def test_api_run_returns_202_with_run_id(tmp_path):
    client = make_client(tmp_path)
    resp = client.post("/api/v1/run", json={})
    assert resp.status_code == 202
    data = resp.get_json()
    assert data["started"] is True
    assert data["run_id"] is not None
    wait_status(client, "success")


def test_api_run_source_is_api(tmp_path):
    client = make_client(tmp_path)
    client.post("/api/v1/run", json={})
    data = client.get("/status").get_json()
    assert data["source"] == "api"
    wait_status(client, "success")


def test_ui_run_source_is_ui(tmp_path):
    client = make_client(tmp_path)
    client.post("/run", data={})
    data = client.get("/status").get_json()
    assert data["source"] == "ui"
    wait_status(client, "success")


def test_api_run_while_running_returns_409(tmp_path):
    client = make_client(tmp_path, script="sleep 5")
    assert client.post("/api/v1/run", json={}).status_code == 202
    assert client.post("/api/v1/run", json={}).status_code == 409
    state_file = tmp_path / "state" / "state.json"
    os.kill(json.loads(state_file.read_text())["pid"], 15)
    wait_status(client, "failed")


def test_api_run_passes_branch_and_flags(tmp_path):
    client = make_client(tmp_path, script='echo "ARGS:$@"')
    client.post("/api/v1/run", json={"branch": "dev/foo", "local": True, "boot": True})
    wait_status(client, "success")
    log = (tmp_path / "state" / "current.log").read_text()
    assert "ARGS:-b dev/foo --local --boot" in log


def test_api_status_returns_state_for_valid_run_id(tmp_path):
    client = make_client(tmp_path)
    run_id = client.post("/api/v1/run", json={}).get_json()["run_id"]
    wait_status(client, "success")
    resp = client.get(f"/api/v1/status/{run_id}")
    assert resp.status_code == 200
    data = resp.get_json()
    assert data["run_id"] == run_id
    assert data["status"] == "success"
    assert data["running"] is False


def test_api_status_returns_404_for_unknown_run_id(tmp_path):
    resp = make_client(tmp_path).get("/api/v1/status/00000000-0000-0000-0000-000000000000")
    assert resp.status_code == 404


def test_api_status_returns_404_after_run_superseded(tmp_path):
    client = make_client(tmp_path)
    old_id = client.post("/api/v1/run", json={}).get_json()["run_id"]
    wait_status(client, "success")
    client.post("/api/v1/run", json={})
    wait_status(client, "success")
    assert client.get(f"/api/v1/status/{old_id}").status_code == 404


def test_api_stream_serves_finished_run(tmp_path):
    client = make_client(tmp_path, script="echo hello")
    run_id = client.post("/api/v1/run", json={}).get_json()["run_id"]
    wait_status(client, "success")
    resp = client.get(f"/api/v1/stream/{run_id}")
    assert resp.content_type.startswith("text/event-stream")
    body = resp.get_data(as_text=True)
    assert "data: hello" in body
    assert "data: [UPGRADE SUCCESSFUL]" in body
    assert body.rstrip().endswith("data: [DONE]")


def test_api_stream_returns_404_for_unknown_run_id(tmp_path):
    resp = make_client(tmp_path).get("/api/v1/stream/00000000-0000-0000-0000-000000000000")
    assert resp.status_code == 404


def test_api_log_returns_content_for_valid_run_id(tmp_path):
    client = make_client(tmp_path, script="echo api-log-test")
    run_id = client.post("/api/v1/run", json={}).get_json()["run_id"]
    wait_status(client, "success")
    resp = client.get(f"/api/v1/log/{run_id}")
    assert resp.status_code == 200
    assert b"api-log-test" in resp.data


def test_api_log_returns_404_for_unknown_run_id(tmp_path):
    resp = make_client(tmp_path).get("/api/v1/log/00000000-0000-0000-0000-000000000000")
    assert resp.status_code == 404
