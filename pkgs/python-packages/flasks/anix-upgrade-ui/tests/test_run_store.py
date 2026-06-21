import json
import os
import subprocess
import sys
import time

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from run_store import REPLAY_CAP_BYTES, RunStore


def make_store(tmp_path):
    return RunStore(str(tmp_path / "state"))


def wait_until_done(store, timeout=10.0):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        state = store.read_state()
        if state.get("status") != "running":
            return state
        time.sleep(0.05)
    pytest.fail("run did not finish in time")


def collect_stream(store, timeout=10.0):
    """Drain the SSE generator, returning the list of data payloads."""
    lines = []
    deadline = time.monotonic() + timeout
    for event in store.stream():
        assert event.startswith("data: ") and event.endswith("\n\n")
        lines.append(event[len("data: "):-2])
        if lines[-1] == "[DONE]" or time.monotonic() > deadline:
            break
    return lines


def test_initial_state_is_idle(tmp_path):
    store = make_store(tmp_path)
    assert store.read_state() == {"status": "idle"}


def test_corrupt_state_file_reads_as_idle(tmp_path):
    store = make_store(tmp_path)
    with open(store.state_path, "w") as f:
        f.write("{not json")
    assert store.read_state() == {"status": "idle"}


def test_successful_run_records_success_and_log(tmp_path):
    store = make_store(tmp_path)
    assert store.start(["sh", "-c", "echo hello; echo world"]) is not None
    state = wait_until_done(store)
    assert state["status"] == "success"
    assert state["returncode"] == 0
    assert state["finished_at"]
    with open(store.log_path) as f:
        assert f.read() == "hello\nworld\n"


def test_failed_run_records_returncode(tmp_path):
    store = make_store(tmp_path)
    assert store.start(["sh", "-c", "echo oops; exit 3"]) is not None
    state = wait_until_done(store)
    assert state["status"] == "failed"
    assert state["returncode"] == 3


def test_run_completes_with_no_reader_attached(tmp_path):
    """Regression: 200KB of output (>> 64KB pipe buffer) with nobody reading.

    The old SSE-coupled design deadlocked here in pipe_write."""
    store = make_store(tmp_path)
    assert store.start(["sh", "-c", "yes x | head -c 200000"]) is not None
    state = wait_until_done(store)
    assert state["status"] == "success"
    assert os.path.getsize(store.log_path) == 200000


def test_start_rejects_concurrent_run(tmp_path):
    store = make_store(tmp_path)
    assert store.start(["sleep", "5"]) is not None
    try:
        assert store.start(["sh", "-c", "echo nope"]) is None
    finally:
        os.kill(store.read_state()["pid"], 15)
        wait_until_done(store)


def test_new_run_truncates_log(tmp_path):
    store = make_store(tmp_path)
    store.start(["sh", "-c", "echo first"])
    wait_until_done(store)
    store.start(["sh", "-c", "echo second"])
    wait_until_done(store)
    with open(store.log_path) as f:
        assert f.read() == "second\n"


def test_stale_running_state_finalized_as_failed(tmp_path):
    store = make_store(tmp_path)
    # A PID that existed but is now dead, with no exit.rc sentinel:
    proc = subprocess.Popen(["true"])
    proc.wait()
    with open(store.state_path, "w") as f:
        json.dump({"status": "running", "pid": proc.pid}, f)
    state = store.read_state()
    assert state["status"] == "failed"
    assert state["returncode"] is None
    # ...and persisted:
    with open(store.state_path) as f:
        assert json.load(f)["status"] == "failed"


def test_stale_running_state_recovers_success_via_rc_sentinel(tmp_path):
    """Simulates nixos-rebuild switch killing the service after proc exits (rc=0)."""
    store = make_store(tmp_path)
    proc = subprocess.Popen(["true"])
    proc.wait()
    with open(store.state_path, "w") as f:
        json.dump({"status": "running", "pid": proc.pid}, f)
    # Simulate _wait() having written the sentinel before being killed:
    with open(store._rc_path, "w") as f:
        f.write("0")
    state = store.read_state()
    assert state["status"] == "success"
    assert state["returncode"] == 0
    assert not os.path.exists(store._rc_path)


def test_stale_running_state_recovers_failure_via_rc_sentinel(tmp_path):
    store = make_store(tmp_path)
    proc = subprocess.Popen(["true"])
    proc.wait()
    with open(store.state_path, "w") as f:
        json.dump({"status": "running", "pid": proc.pid}, f)
    with open(store._rc_path, "w") as f:
        f.write("2")
    state = store.read_state()
    assert state["status"] == "failed"
    assert state["returncode"] == 2
    assert not os.path.exists(store._rc_path)


def test_stale_running_state_recovers_success_via_log_inference(tmp_path):
    """Simulates service killed while subprocess was still running (no exit.rc).

    anix-upgrade writes to the log and exits 0; absence of the failure string
    in a non-empty log should be inferred as success.
    """
    store = make_store(tmp_path)
    proc = subprocess.Popen(["true"])
    proc.wait()
    os.makedirs(os.path.dirname(store.log_path), exist_ok=True)
    with open(store.log_path, "wb") as f:
        f.write(b"building...\nDone.\n")
    with open(store.state_path, "w") as f:
        json.dump({"status": "running", "pid": proc.pid}, f)
    state = store.read_state()
    assert state["status"] == "success"
    assert state["returncode"] == 0


def test_stale_running_state_recovers_failure_via_log_inference(tmp_path):
    """Log containing 'Build/switch failed.' should be inferred as failure."""
    store = make_store(tmp_path)
    proc = subprocess.Popen(["true"])
    proc.wait()
    os.makedirs(os.path.dirname(store.log_path), exist_ok=True)
    with open(store.log_path, "wb") as f:
        f.write(b"building...\nBuild/switch failed.\n")
    with open(store.state_path, "w") as f:
        json.dump({"status": "running", "pid": proc.pid}, f)
    state = store.read_state()
    assert state["status"] == "failed"
    assert state["returncode"] == 1


def test_start_clears_stale_rc_sentinel(tmp_path):
    store = make_store(tmp_path)
    with open(store._rc_path, "w") as f:
        f.write("0")
    store.start(["sh", "-c", "echo hi"])
    wait_until_done(store)
    assert not os.path.exists(store._rc_path)


def test_spawn_failure_records_failed_and_logs_error(tmp_path):
    store = make_store(tmp_path)
    assert store.start(["/nonexistent/binary"]) is not None
    state = store.read_state()
    assert state["status"] == "failed"
    with open(store.log_path) as f:
        assert "[ERROR:" in f.read()


def test_stream_replays_finished_run(tmp_path):
    store = make_store(tmp_path)
    store.start(["sh", "-c", "echo hello; echo world"])
    wait_until_done(store)
    lines = collect_stream(store)
    assert lines == ["hello", "world", "[UPGRADE SUCCESSFUL]", "[DONE]"]


def test_stream_reports_failure(tmp_path):
    store = make_store(tmp_path)
    store.start(["sh", "-c", "exit 7"])
    wait_until_done(store)
    lines = collect_stream(store)
    assert "[UPGRADE FAILED (exit 7)]" in lines
    assert lines[-1] == "[DONE]"


def test_stream_with_no_log_reports_no_output(tmp_path):
    store = make_store(tmp_path)
    lines = collect_stream(store)
    assert lines == ["[no upgrade output]", "[DONE]"]


def test_stream_follows_live_run(tmp_path):
    store = make_store(tmp_path)
    store.start(["sh", "-c", "echo one; sleep 1; echo two"])
    lines = collect_stream(store)
    assert lines == ["one", "two", "[UPGRADE SUCCESSFUL]", "[DONE]"]


def test_stream_caps_replay_and_drops_partial_line(tmp_path):
    store = make_store(tmp_path)
    os.makedirs(os.path.dirname(store.log_path), exist_ok=True)
    # 100 KB over the cap, in 100-byte lines:
    line = "x" * 99 + "\n"
    total = REPLAY_CAP_BYTES + 100 * 1024
    with open(store.log_path, "w") as f:
        f.write(line * (total // 100))
    with open(store.state_path, "w") as f:
        json.dump({"status": "success", "returncode": 0}, f)
    lines = collect_stream(store, timeout=30.0)
    payload = sum(len(l) + 1 for l in lines[:-2])
    assert payload <= REPLAY_CAP_BYTES
    # cap landed mid-line; the partial first line must have been dropped:
    assert all(l == "x" * 99 for l in lines[:-2])
