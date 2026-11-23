"""Direct ComfyUI client for workflows cozy cannot carry (3D outputs)."""
import os
import time
import uuid

import requests


class ComfyError(Exception):
    pass


class ComfyClient:
    def __init__(self, url, poll=2.0, session=None):
        self.url = url.rstrip("/")
        self.poll = poll
        self.http = session or requests.Session()
        self.client_id = uuid.uuid4().hex

    def _req(self, method, path, **kw):
        try:
            return self.http.request(method, self.url + path, timeout=120, **kw)
        except requests.RequestException as e:
            raise ComfyError("ComfyUI unreachable at %s: %s" % (self.url, e))

    def upload_image(self, path, subfolder="aiart"):
        with open(path, "rb") as f:
            r = self._req("POST", "/upload/image",
                          files={"image": (os.path.basename(path), f)},
                          data={"subfolder": subfolder, "overwrite": "true"})
        if r.status_code != 200:
            raise ComfyError("upload failed (%s): %s" % (r.status_code, r.text))
        info = r.json()
        return "%s/%s" % (info["subfolder"], info["name"]) if info.get("subfolder") else info["name"]

    def submit(self, graph):
        r = self._req("POST", "/prompt",
                      json={"prompt": graph, "client_id": self.client_id})
        if r.status_code != 200:
            raise ComfyError("prompt rejected (%s): %s" % (r.status_code, r.text))
        return r.json()["prompt_id"]

    def free(self):
        self._req("POST", "/free", json={"unload_models": True, "free_memory": True})

    def wait(self, prompt_id, on_progress=None, timeout=3600):
        start = time.monotonic()
        while time.monotonic() - start < timeout:
            r = self._req("GET", "/history/" + prompt_id)
            entry = r.json().get(prompt_id) if r.status_code == 200 else None
            if entry:
                status = entry.get("status", {})
                if status.get("status_str") == "error":
                    msgs = [m for m in status.get("messages", [])
                            if m and m[0] == "execution_error"]
                    detail = msgs[-1][1].get("exception_message") if msgs else status
                    raise ComfyError("ComfyUI execution failed: %s" % detail)
                if status.get("completed", True):
                    return entry.get("outputs", {})
            if on_progress:
                on_progress("elapsed", time.monotonic() - start, None)
            time.sleep(self.poll)
        raise ComfyError("timed out waiting for prompt %s" % prompt_id)

    def fetch(self, item, dest):
        r = self._req("GET", "/view", params={
            "filename": item["filename"], "subfolder": item.get("subfolder", ""),
            "type": item.get("type", "output")})
        if r.status_code != 200:
            raise ComfyError("could not fetch %s" % item["filename"])
        with open(dest, "wb") as f:
            f.write(r.content)
        return dest
