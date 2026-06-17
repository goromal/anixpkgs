import io
import json
from unittest import mock

import comfyui_client


def _resp(payload_bytes):
    m = mock.MagicMock()
    m.read.return_value = payload_bytes
    m.__enter__.return_value = m
    m.__exit__.return_value = False
    return m


def test_submit_posts_prompt_and_returns_id():
    c = comfyui_client.ComfyUIClient("http://h:8188")
    with mock.patch("urllib.request.urlopen", return_value=_resp(b'{"prompt_id": "abc"}')) as uo:
        out = c.submit({"1": {}}, "cid-1")
    assert out == "abc"
    req = uo.call_args[0][0]
    assert req.full_url == "http://h:8188/prompt"
    assert json.loads(req.data) == {"prompt": {"1": {}}, "client_id": "cid-1"}


def test_history_gets_and_parses():
    c = comfyui_client.ComfyUIClient("http://h:8188/")
    with mock.patch("urllib.request.urlopen", return_value=_resp(b'{"abc": {"outputs": {}}}')) as uo:
        out = c.history("abc")
    assert out == {"abc": {"outputs": {}}}
    assert uo.call_args[0][0] == "http://h:8188/history/abc"


def test_view_returns_bytes_with_query():
    c = comfyui_client.ComfyUIClient("http://h:8188")
    with mock.patch("urllib.request.urlopen", return_value=_resp(b"PNGDATA")) as uo:
        out = c.view("f.png", "sub", "output")
    assert out == b"PNGDATA"
    url = uo.call_args[0][0]
    assert url.startswith("http://h:8188/view?")
    assert "filename=f.png" in url and "subfolder=sub" in url and "type=output" in url


def test_ws_url_derivation():
    assert comfyui_client.ComfyUIClient("http://h:8188").ws_url() == "ws://h:8188/ws"
    assert comfyui_client.ComfyUIClient("https://h").ws_url() == "wss://h/ws"


def test_events_recv_skips_binary():
    fake_ws = mock.MagicMock()
    fake_ws.recv.side_effect = [b"\x00\x01", json.dumps({"type": "progress"})]
    with mock.patch("websocket.WebSocket", return_value=fake_ws):
        c = comfyui_client.ComfyUIClient("http://h:8188")
        ev = c.connect_events("cid")
        assert ev.recv() == {"type": "progress"}
    fake_ws.connect.assert_called_once()
