"""2D generation through cozy's queue API.

Going through cozy rather than straight to ComfyUI reuses its tuned workflows,
OOM retry and GPU lock, and makes every agent job visible in the cozy page.
"""
import os
import shutil
import time
import uuid

import requests


class CozyError(Exception):
    pass


class CozyClient:
    def __init__(self, url, token_file=None, input_dir=None, poll=3.0,
                 session=None):
        self.url = url.rstrip("/")
        self.input_dir = input_dir
        self.poll = poll
        self.http = session or requests.Session()
        token = os.environ.get("COZY_TOKEN")
        if not token and token_file:
            try:
                with open(os.path.expanduser(token_file)) as f:
                    token = f.read().strip()
            except OSError:
                token = None
        if token:
            self.http.headers["Authorization"] = "Bearer " + token

    def _req(self, method, path, **kw):
        try:
            r = self.http.request(method, self.url + path, timeout=60, **kw)
        except requests.RequestException as e:
            raise CozyError("cozy unreachable at %s: %s" % (self.url, e))
        if r.status_code == 401:
            raise CozyError("cozy rejected the API token (see cozy API.md)")
        return r

    def stage_input(self, path):
        """Copy a local image into cozy's input dir; return the job's `image`."""
        if not self.input_dir:
            raise CozyError("no cozy input dir configured")
        dest_dir = os.path.join(self.input_dir, "aiart")
        os.makedirs(dest_dir, exist_ok=True)
        ext = os.path.splitext(path)[1].lower() or ".png"
        name = uuid.uuid4().hex[:12] + ext
        shutil.copyfile(path, os.path.join(dest_dir, name))
        return "aiart/" + name

    def add(self, job):
        r = self._req("POST", "/api/queue/add", json=job)
        if r.status_code != 200:
            raise CozyError("queue/add failed (%s): %s" % (r.status_code, r.text))
        self._req("POST", "/api/queue/start")
        return r.json()["id"]

    def status(self):
        r = self._req("GET", "/api/queue/status")
        r.raise_for_status()
        return r.json()

    def wait(self, job_id, on_progress=None, timeout=3600):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            snap = self.status()
            for res in snap.get("results", []):
                if res["id"] == job_id:
                    if res.get("status") != "success":
                        raise CozyError("job %s %s: %s" % (
                            job_id, res.get("status"), res.get("error")))
                    return res
            cur = snap.get("current") or {}
            if on_progress:
                if cur.get("id") == job_id:
                    on_progress("running", cur.get("progress", 0), cur.get("eta"))
                else:
                    ahead = [j["id"] for j in snap.get("jobs", [])]
                    pos = ahead.index(job_id) + 1 if job_id in ahead else 0
                    on_progress("queued", pos, snap.get("total_eta"))
            time.sleep(self.poll)
        raise CozyError("timed out waiting for job %s" % job_id)

    def download(self, job_id, dest):
        r = self._req("GET", "/api/queue/image", params={"id": job_id})
        if r.status_code != 200:
            raise CozyError("no image for job %s" % job_id)
        with open(dest, "wb") as f:
            f.write(r.content)
        return dest

    def run(self, job, dest, on_progress=None):
        job_id = self.add(job)
        self.wait(job_id, on_progress=on_progress)
        return self.download(job_id, dest)
