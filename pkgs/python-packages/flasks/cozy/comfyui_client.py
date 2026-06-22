import json
import urllib.parse
import urllib.request

import websocket


class WsEvents:
    """Wraps a ComfyUI websocket; recv() returns the next JSON message dict,
    skipping binary preview frames."""

    def __init__(self, ws):
        self._ws = ws

    def recv(self):
        while True:
            msg = self._ws.recv()
            if isinstance(msg, (bytes, bytearray)):
                continue
            return json.loads(msg)

    def close(self):
        try:
            self._ws.close()
        except Exception:
            pass


class ComfyUIClient:
    def __init__(self, base_url):
        self.base_url = base_url.rstrip("/")

    def ws_url(self):
        if self.base_url.startswith("https://"):
            return "wss://" + self.base_url[len("https://"):] + "/ws"
        return "ws://" + self.base_url[len("http://"):] + "/ws"

    def submit(self, graph, client_id):
        data = json.dumps({"prompt": graph, "client_id": client_id}).encode()
        req = urllib.request.Request(
            self.base_url + "/prompt", data=data,
            headers={"Content-Type": "application/json"},
        )
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read())["prompt_id"]

    def free(self):
        """Unload models and free memory so the next job starts cold.

        On unified-memory devices (Jetson) the model working set nearly
        fills RAM and ComfyUI never evicts the CPU-resident text encoder
        between runs, so back-to-back jobs OOM. Calling /free first gives
        each job a clean pool. Best-effort: never raises."""
        data = json.dumps({"unload_models": True, "free_memory": True}).encode()
        req = urllib.request.Request(
            self.base_url + "/free", data=data,
            headers={"Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(req) as resp:
                resp.read()
        except Exception:
            pass

    def history(self, prompt_id):
        with urllib.request.urlopen(self.base_url + "/history/" + prompt_id) as resp:
            return json.loads(resp.read())

    def view(self, filename, subfolder, ftype):
        q = urllib.parse.urlencode(
            {"filename": filename, "subfolder": subfolder, "type": ftype}
        )
        with urllib.request.urlopen(self.base_url + "/view?" + q) as resp:
            return resp.read()

    def connect_events(self, client_id):
        ws = websocket.WebSocket()
        ws.connect(self.ws_url() + "?clientId=" + client_id)
        return WsEvents(ws)
