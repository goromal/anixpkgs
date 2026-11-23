import json
import socket
import threading

import pytest

from aiart import blender, projects, tui
from aiart.cli import build_parser
from aiart.cozy import CozyClient, CozyError


class FakeResponse:
    def __init__(self, status=200, body=None, content=b""):
        self.status_code = status
        self._body = body or {}
        self.content = content
        self.text = json.dumps(self._body)

    def json(self):
        return self._body

    def raise_for_status(self):
        if self.status_code >= 400:
            raise RuntimeError(self.status_code)


class FakeCozy:
    def __init__(self, final_status="success"):
        self.headers = {}
        self.calls = []
        self.polls = 0
        self.final_status = final_status

    def request(self, method, url, **kw):
        path = url.split("/cozy", 1)[1]
        self.calls.append((method, path, kw.get("json")))
        if path == "/api/queue/add":
            return FakeResponse(body={"id": "j1", "eta": 3})
        if path == "/api/queue/start":
            return FakeResponse(409)
        if path == "/api/queue/status":
            self.polls += 1
            if self.polls < 2:
                return FakeResponse(body={"jobs": [{"id": "j1"}], "current": None, "results": []})
            return FakeResponse(body={"jobs": [], "current": None, "results": [
                {"id": "j1", "status": self.final_status, "error": "boom"}]})
        if path == "/api/queue/image":
            return FakeResponse(content=b"PNG")
        return FakeResponse(404)


def test_cozy_run_queues_waits_downloads(tmp_path):
    fake = FakeCozy()
    c = CozyClient("http://h/cozy", poll=0, session=fake)
    c.http.headers.clear()
    dest = c.run({"workflow": "imggen", "prompt": "cat"}, str(tmp_path / "o.png"))
    assert open(dest, "rb").read() == b"PNG"
    assert fake.calls[0] == ("POST", "/api/queue/add", {"workflow": "imggen", "prompt": "cat"})


def test_cozy_failure_surfaces(tmp_path):
    c = CozyClient("http://h/cozy", poll=0, session=FakeCozy("failed"))
    with pytest.raises(CozyError, match="boom"):
        c.run({"workflow": "imggen"}, str(tmp_path / "o.png"))


def test_cozy_stage_input(tmp_path):
    src = tmp_path / "in.jpg"
    src.write_bytes(b"x")
    c = CozyClient("http://h/cozy", input_dir=str(tmp_path / "input"), session=FakeCozy())
    rel = c.stage_input(str(src))
    assert rel.startswith("aiart/") and rel.endswith(".jpg")
    assert (tmp_path / "input" / rel).read_bytes() == b"x"


def test_bridge_client_round_trip(tmp_path, monkeypatch):
    srv = socket.socket()
    srv.bind(("127.0.0.1", 0))
    srv.listen()
    state = tmp_path / "state.json"
    state.write_text(json.dumps({"port": srv.getsockname()[1], "token": "t"}))
    monkeypatch.setenv("AIART_BRIDGE_STATE", str(state))
    seen = {}

    def serve():
        conn, _ = srv.accept()
        with conn, conn.makefile("rwb") as f:
            seen.update(json.loads(f.readline()))
            f.write(b'{"ok": true, "result": [1], "stdout": ""}\n')
            f.flush()

    t = threading.Thread(target=serve)
    t.start()
    assert blender.exec_code("result=[1]")["result"] == [1]
    t.join()
    srv.close()
    assert seen == {"token": "t", "op": "exec", "code": "result=[1]"}


def test_bridge_without_live_blender(tmp_path, monkeypatch):
    monkeypatch.setenv("AIART_BRIDGE_STATE", str(tmp_path / "none.json"))
    with pytest.raises(blender.BlenderError, match="aiart blender open"):
        blender.call("ping")


def test_opening_prompt_names_skill(tmp_path):
    p = projects.create(tmp_path, "keep", "3d")
    cmd = tui.agent_command("claude", p)
    assert cmd[0] == "claude" and "aiart-3d" in cmd[1] and p.root in cmd[1]


def test_parser_shapes():
    ap = build_parser()
    a = ap.parse_args(["mesh", "gen", "--image", "x.png", "--set", "steps=40"])
    assert a.set == [("steps", 40)]
    a = ap.parse_args(["image", "edit", "a.png", "make it red", "--rect", "1,2,3,4"])
    assert a.rect == {"x": 1, "y": 2, "w": 3, "h": 4}


def test_models_list_runs(tmp_path, monkeypatch, capsys):
    from aiart import cli
    cfg = tmp_path / "cfg.json"
    cfg.write_text(json.dumps({"comfyModelsDir": str(tmp_path)}))
    monkeypatch.setenv("AIART_CONFIG", str(cfg))
    assert cli.main(["models", "list"]) == 0
    assert "hunyuan3d21" in capsys.readouterr().out
