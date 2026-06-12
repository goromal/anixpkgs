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
    assert resp.get_json() == {"started": True}
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


def test_list_dirs_works(tmp_path):
    client = make_client(tmp_path)
    (tmp_path / "subdir").mkdir()
    resp = client.post("/api/list-dirs", json={"path": str(tmp_path)})
    assert resp.status_code == 200
    assert "subdir" in resp.get_json()["dirs"]
