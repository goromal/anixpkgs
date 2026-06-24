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
    (tmp_path / "secret.txt").write_text("nope")
    (tmp_path / "imgedit.api.json").write_text("{}")
    app = cozy.create_app(store=store, workflows=["imggen", "imgedit"],
                          workflow_dir=str(tmp_path), subdomain="/cozy",
                          input_dir=str(img_dir),
                          workflow_kinds={"imggen": "generate", "imgedit": "edit"})
    app.config["TESTING"] = True
    app.config["WTF_CSRF_ENABLED"] = False
    c = app.test_client()
    c._store = store
    return c


def test_input_images_lists(edit_client):
    _login(edit_client)
    r = edit_client.get("/cozy/api/input-images")
    assert "me.png" in r.get_json()["images"]


def test_input_image_serves_and_rejects_traversal(edit_client):
    _login(edit_client)
    assert edit_client.get("/cozy/api/input-image?name=me.png").status_code == 200
    assert edit_client.get("/cozy/api/input-image?name=../secret.txt").status_code == 404
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
