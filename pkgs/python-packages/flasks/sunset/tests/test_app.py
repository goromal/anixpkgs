import signal

import sunset


def _client():
    app = sunset.create_app()
    app.config["TESTING"] = True
    return app.test_client()


def test_status_not_running(monkeypatch):
    monkeypatch.setattr(sunset, "_scan_dolphin", lambda: iter([]))
    data = _client().get("/status").get_json()
    assert data == {"running": False, "pid": None, "game": None}


def test_status_running_parses_game(monkeypatch):
    argv = [
        "/nix/store/x/bin/dolphin-emu", "-a", "LLE",
        "-e", "/home/andrew/more-games/TwilightPrincess.iso",
    ]
    monkeypatch.setattr(sunset, "_scan_dolphin", lambda: iter([(4242, argv)]))
    data = _client().get("/status").get_json()
    assert data == {"running": True, "pid": 4242, "game": "TwilightPrincess"}


def test_kill_sigkills_only_matched(monkeypatch):
    argv = ["/x/bin/dolphin-emu", "-e", "/g/Melee.iso"]
    monkeypatch.setattr(sunset, "_scan_dolphin", lambda: iter([(99, argv)]))
    calls = []
    monkeypatch.setattr(sunset.os, "kill", lambda pid, sig: calls.append((pid, sig)))
    data = _client().post("/kill").get_json()
    assert data == {"killed": [99]}
    assert calls == [(99, signal.SIGKILL)]


def test_kill_nothing_running(monkeypatch):
    monkeypatch.setattr(sunset, "_scan_dolphin", lambda: iter([]))

    def _boom(pid, sig):
        raise AssertionError("os.kill must not be called")

    monkeypatch.setattr(sunset.os, "kill", _boom)
    data = _client().post("/kill").get_json()
    assert data == {"killed": []}


def test_game_from_argv_no_iso():
    assert sunset._game_from_argv(["/x/bin/dolphin-emu"]) is None
