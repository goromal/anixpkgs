import os

import pytest

import cozy


class FakeStore:
    def __init__(self):
        self._running = False
        self.cleared = False
        self.started = None
        self.image_path = "/nonexistent/output.png"

    def read_state(self):
        return {"workflow": "imggen", "prompt": "p", "width": 400, "height": 800,
                "image": "",
                "job": {"status": "running" if self._running else "idle",
                        "progress": 42, "error": None,
                        "started_at": "2026-06-23T10:00:00-06:00",
                        "finished_at": "2026-06-23T10:00:30-06:00"},
                "output": False}

    def set_inputs(self, **kw):
        pass

    def start(self, name, path, prompt, w, h, image=""):
        if self._running:
            return False
        self._running = True
        self.started = (name, prompt, w, h, image)
        return True

    def clear(self):
        self.cleared = True


@pytest.fixture
def client(tmp_path):
    store = FakeStore()
    app = cozy.create_app(store=store, workflows=["imggen", "imggen2"],
                          workflow_dir=str(tmp_path), subdomain="/cozy")
    app.config["TESTING"] = True
    app.config["WTF_CSRF_ENABLED"] = False
    c = app.test_client()
    c._store = store
    return c


def _login(c):
    return c.post("/cozy/login", data={"username": "anonymous", "password": "test"},
                  follow_redirects=False)


def test_index_requires_login(client):
    r = client.get("/cozy/", follow_redirects=False)
    assert r.status_code in (301, 302)


def test_status_requires_login(client):
    r = client.get("/cozy/api/status", follow_redirects=False)
    assert r.status_code in (301, 302, 401)


def test_unknown_workflow_400(client, monkeypatch):
    monkeypatch.setattr(cozy, "_check_password", lambda pw: True)
    _login(client)
    r = client.post("/cozy/api/generate", json={"workflow": "nope", "prompt": "x",
                                                 "width": 400, "height": 800})
    assert r.status_code == 400


def test_generate_then_conflict(client, monkeypatch, tmp_path):
    monkeypatch.setattr(cozy, "_check_password", lambda pw: True)
    open(os.path.join(str(tmp_path), "imggen.api.json"), "w").write("{}")
    _login(client)
    r1 = client.post("/cozy/api/generate", json={"workflow": "imggen", "prompt": "x",
                                                 "width": 400, "height": 800})
    assert r1.status_code == 200
    assert client._store.started == ("imggen", "x", 400, 800, "")
    r2 = client.post("/cozy/api/generate", json={"workflow": "imggen", "prompt": "x",
                                                 "width": 400, "height": 800})
    assert r2.status_code == 409


def test_status_and_clear(client, monkeypatch):
    monkeypatch.setattr(cozy, "_check_password", lambda pw: True)
    _login(client)
    s = client.get("/cozy/api/status")
    assert s.status_code == 200
    body = s.get_json()
    assert body["status"] == "idle" and body["progress"] == 42 and body["has_image"] is False
    assert body["duration"] == 30.0
    c = client.post("/cozy/api/clear")
    assert c.status_code == 200
    assert client._store.cleared is True


@pytest.fixture
def edit_client(tmp_path, monkeypatch):
    monkeypatch.setattr(cozy, "_check_password", lambda pw: True)
    store = FakeStore()
    img_dir = tmp_path / "input"
    img_dir.mkdir()
    (img_dir / "me.png").write_bytes(b"\x89PNG\r\n")
    out_dir = tmp_path / "output"
    out_dir.mkdir()
    (out_dir / "gen.png").write_bytes(b"\x89PNG\r\n")
    (tmp_path / "secret.txt").write_text("nope")
    (tmp_path / "imgedit.api.json").write_text("{}")
    app = cozy.create_app(store=store, workflows=["imggen", "imgedit"],
                          workflow_dir=str(tmp_path), subdomain="/cozy",
                          input_dir=str(img_dir), output_dir=str(out_dir),
                          workflow_kinds={"imggen": "generate", "imgedit": "edit"})
    app.config["TESTING"] = True
    app.config["WTF_CSRF_ENABLED"] = False
    c = app.test_client()
    c._store = store
    return c


def test_input_images_lists_both_dirs(edit_client):
    _login(edit_client)
    items = edit_client.get("/cozy/api/input-images").get_json()["images"]
    by_value = {it["value"]: it for it in items}
    # input-dir files keep a bare relative path; output-dir files carry the
    # ComfyUI ' [output]' annotation so LoadImage reads them from the output dir.
    assert by_value["me.png"]["source"] == "input"
    assert by_value["gen.png [output]"]["source"] == "output"
    assert by_value["gen.png [output]"]["label"] == "gen.png"


def test_input_image_serves_from_both_dirs_and_rejects_traversal(edit_client):
    _login(edit_client)
    assert edit_client.get("/cozy/api/input-image?name=me.png").status_code == 200
    assert edit_client.get(
        "/cozy/api/input-image?name=gen.png [output]").status_code == 200
    assert edit_client.get("/cozy/api/input-image?name=../secret.txt").status_code == 404
    assert edit_client.get(
        "/cozy/api/input-image?name=../secret.txt [output]").status_code == 404
    assert edit_client.get("/cozy/api/input-image?name=missing.png").status_code == 404


def test_edit_generate_requires_image(edit_client):
    _login(edit_client)
    bad = edit_client.post("/cozy/api/generate",
                           json={"workflow": "imgedit", "prompt": "hi"})
    assert bad.status_code == 400
    ok = edit_client.post("/cozy/api/generate",
                          json={"workflow": "imgedit", "prompt": "hi", "image": "me.png"})
    assert ok.status_code == 200
    assert edit_client._store.started[0] == "imgedit"


def test_edit_generate_accepts_output_image(edit_client):
    _login(edit_client)
    # A prior generation, picked from the output dir, re-fed as the edit input.
    ok = edit_client.post(
        "/cozy/api/generate",
        json={"workflow": "imgedit", "prompt": "hi", "image": "gen.png [output]"})
    assert ok.status_code == 200
    # The annotated value is passed through verbatim to the job store (and on to
    # ComfyUI's LoadImage), not stripped.
    assert edit_client._store.started[4] == "gen.png [output]"


def test_edit_generate_rejects_output_traversal(edit_client):
    _login(edit_client)
    bad = edit_client.post(
        "/cozy/api/generate",
        json={"workflow": "imgedit", "prompt": "hi", "image": "../secret.txt [output]"})
    assert bad.status_code == 400


def _restart_client(tmp_path, monkeypatch, restart_cmd):
    monkeypatch.setattr(cozy, "_check_password", lambda pw: True)
    app = cozy.create_app(store=FakeStore(), workflows=["imggen"],
                          workflow_dir=str(tmp_path), subdomain="/cozy",
                          restart_cmd=restart_cmd)
    app.config["TESTING"] = True
    app.config["WTF_CSRF_ENABLED"] = False
    return app.test_client()


def test_restart_disabled_when_unconfigured(tmp_path, monkeypatch):
    c = _restart_client(tmp_path, monkeypatch, None)
    _login(c)
    r = c.post("/cozy/api/restart-comfyui")
    assert r.status_code == 503
    # The button is hidden from the page when no restart command is configured.
    assert b'id="restart"' not in c.get("/cozy/").data


def test_restart_runs_configured_command(tmp_path, monkeypatch):
    calls = []
    monkeypatch.setattr(cozy.subprocess, "run",
                        lambda cmd, **kw: calls.append(cmd) or None)
    c = _restart_client(tmp_path, monkeypatch, ["systemctl", "restart", "comfyui.service"])
    _login(c)
    r = c.post("/cozy/api/restart-comfyui")
    assert r.status_code == 200 and r.get_json()["ok"] is True
    assert calls == [["systemctl", "restart", "comfyui.service"]]
    assert b'id="restart"' in c.get("/cozy/").data


def test_restart_reports_command_failure(tmp_path, monkeypatch):
    def boom(cmd, **kw):
        raise cozy.subprocess.CalledProcessError(1, cmd, stderr="unit not found")
    monkeypatch.setattr(cozy.subprocess, "run", boom)
    c = _restart_client(tmp_path, monkeypatch, ["systemctl", "restart", "comfyui.service"])
    _login(c)
    r = c.post("/cozy/api/restart-comfyui")
    assert r.status_code == 500
    assert r.get_json()["error"] == "unit not found"


def _flush_client(tmp_path, monkeypatch):
    monkeypatch.setattr(cozy, "_check_password", lambda pw: True)
    in_dir = tmp_path / "input"
    in_dir.mkdir()
    out_dir = tmp_path / "output"
    out_dir.mkdir()
    app = cozy.create_app(store=FakeStore(), workflows=["imggen"],
                          workflow_dir=str(tmp_path), subdomain="/cozy",
                          input_dir=str(in_dir), output_dir=str(out_dir))
    app.config["TESTING"] = True
    app.config["WTF_CSRF_ENABLED"] = False
    c = app.test_client()
    c._in_dir, c._out_dir = in_dir, out_dir
    return c


def test_flush_button_always_present(tmp_path, monkeypatch):
    c = _flush_client(tmp_path, monkeypatch)
    _login(c)
    assert b'id="flush"' in c.get("/cozy/").data


def test_flush_runs_existing_scripts_only(tmp_path, monkeypatch):
    calls = []
    monkeypatch.setattr(cozy.subprocess, "run",
                        lambda cmd, **kw: calls.append((cmd, kw.get("cwd"))) or None)
    c = _flush_client(tmp_path, monkeypatch)
    _login(c)
    # Neither script exists yet: no-op, ran == 0.
    r = c.post("/cozy/api/flush")
    assert r.status_code == 200 and r.get_json() == {"ok": True, "ran": 0}
    assert calls == []
    # Only the input-dir script exists: run just that one.
    script = c._in_dir / "flush.sh"
    script.write_text("#!/usr/bin/env bash\n")
    r = c.post("/cozy/api/flush")
    assert r.status_code == 200 and r.get_json()["ran"] == 1
    assert calls == [(["bash", str(script)], str(c._in_dir))]


def test_flush_reports_script_failure(tmp_path, monkeypatch):
    def boom(cmd, **kw):
        raise cozy.subprocess.CalledProcessError(1, cmd, stderr="disk full")
    c = _flush_client(tmp_path, monkeypatch)
    (c._out_dir / "flush.sh").write_text("#!/usr/bin/env bash\n")
    monkeypatch.setattr(cozy.subprocess, "run", boom)
    _login(c)
    r = c.post("/cozy/api/flush")
    assert r.status_code == 500
    assert r.get_json()["error"] == "disk full"
