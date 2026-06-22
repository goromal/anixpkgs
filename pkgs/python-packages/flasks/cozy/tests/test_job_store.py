import json
import os

import job_store


class FakeEvents:
    def __init__(self, msgs):
        self._msgs = list(msgs)

    def recv(self):
        return self._msgs.pop(0)

    def close(self):
        pass


class FakeClient:
    """Drives JobStore deterministically: events then history/view."""

    def __init__(self, events_msgs, history=None, image=b"IMG"):
        self._events_msgs = events_msgs
        self._history = history or {}
        self._image = image
        self.submitted = None
        self.freed = False

    def free(self):
        self.freed = True

    def connect_events(self, client_id):
        return FakeEvents(self._events_msgs)

    def submit(self, graph, client_id):
        self.submitted = graph
        return "pid-1"

    def history(self, prompt_id):
        return self._history

    def view(self, filename, subfolder, ftype):
        return self._image


def _fixture_path():
    return os.path.join(os.path.dirname(__file__), "fixtures", "imggen.api.json")


def _wait_idle(store, timeout=5.0):
    import time
    end = time.time() + timeout
    while time.time() < end:
        st = store.read_state()
        if st["job"]["status"] != "running":
            return st
        time.sleep(0.02)
    return store.read_state()


def test_fresh_defaults(tmp_path):
    store = job_store.JobStore(str(tmp_path), FakeClient([]))
    st = store.read_state()
    assert st["job"]["status"] == "idle"
    assert st["width"] == 400 and st["height"] == 800


def test_set_inputs_persists_across_instances(tmp_path):
    job_store.JobStore(str(tmp_path), FakeClient([])).set_inputs(
        workflow="imggen2", prompt="hi", width=512, height=768)
    st = job_store.JobStore(str(tmp_path), FakeClient([])).read_state()
    assert st["workflow"] == "imggen2"
    assert st["prompt"] == "hi"
    assert st["width"] == 512 and st["height"] == 768


def test_start_runs_to_success(tmp_path):
    events = [
        {"type": "progress", "data": {"value": 5, "max": 10, "prompt_id": "pid-1"}},
        {"type": "executing", "data": {"node": None, "prompt_id": "pid-1"}},
    ]
    history = {"pid-1": {"outputs": {"9": {"images": [
        {"filename": "out.png", "subfolder": "", "type": "output"}]}}}}
    client = FakeClient(events, history=history, image=b"PNGBYTES")
    store = job_store.JobStore(str(tmp_path), client)
    assert store.start("imggen", _fixture_path(), "a cat", 400, 800) is True
    st = _wait_idle(store)
    assert st["job"]["status"] == "success"
    assert st["job"]["progress"] == 100
    assert st["output"] is True
    assert open(os.path.join(str(tmp_path), "output.png"), "rb").read() == b"PNGBYTES"


def test_start_rejected_when_running(tmp_path):
    store = job_store.JobStore(str(tmp_path), FakeClient([]))
    store._write_state({**store._default_state(),
                        "job": {"status": "running", "prompt_id": "x",
                                "progress": 0, "started_at": None,
                                "finished_at": None, "error": None}})
    assert store.start("imggen", _fixture_path(), "x", 400, 800) is False


def test_clear_keeps_dimensions(tmp_path):
    store = job_store.JobStore(str(tmp_path), FakeClient([]))
    store.set_inputs(workflow="imggen", prompt="keep?", width=300, height=600)
    open(os.path.join(str(tmp_path), "output.png"), "wb").write(b"X")
    store.clear()
    st = store.read_state()
    assert st["prompt"] == ""
    assert st["output"] is False
    assert st["job"]["status"] == "idle"
    assert st["width"] == 300 and st["height"] == 600
    assert st["workflow"] == "imggen"


def test_orphan_finalized_to_success(tmp_path):
    history = {"pid-9": {"outputs": {"9": {"images": [
        {"filename": "out.png", "subfolder": "", "type": "output"}]}}}}
    client = FakeClient([], history=history, image=b"ZZ")
    store = job_store.JobStore(str(tmp_path), client)
    store._write_state({**store._default_state(),
                        "job": {"status": "running", "prompt_id": "pid-9",
                                "progress": 50, "started_at": None,
                                "finished_at": None, "error": None}})
    st = store.read_state()
    assert st["job"]["status"] == "success"
    assert st["output"] is True


def test_orphan_without_history_fails(tmp_path):
    client = FakeClient([], history={})
    store = job_store.JobStore(str(tmp_path), client)
    store._write_state({**store._default_state(),
                        "job": {"status": "running", "prompt_id": "pid-x",
                                "progress": 50, "started_at": None,
                                "finished_at": None, "error": None}})
    st = store.read_state()
    assert st["job"]["status"] == "failed"
