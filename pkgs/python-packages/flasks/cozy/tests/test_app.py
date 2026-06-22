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
                        "progress": 42, "error": None},
                "output": False}

    def set_inputs(self, **kw):
        pass

    def start(self, name, path, prompt, w, h):
        if self._running:
            return False
        self._running = True
        self.started = (name, prompt, w, h)
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
    assert client._store.started == ("imggen", "x", 400, 800)
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
    c = client.post("/cozy/api/clear")
    assert c.status_code == 200
    assert client._store.cleared is True
