import json
import os
import threading
import time
import uuid
from datetime import datetime, timezone

import workflows

DEFAULT_W = 400
DEFAULT_H = 800


def _now():
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def _idle_job():
    return {"status": "idle", "prompt_id": None, "progress": 0,
            "started_at": None, "finished_at": None, "error": None}


def job_duration(job):
    """Wall-clock seconds from started_at to finished_at, or None if either
    timestamp is missing or unparseable. Used by the UI to report how long the
    most recent generation took. Negative deltas (clock skew) collapse to None.
    """
    started = job.get("started_at")
    finished = job.get("finished_at")
    if not started or not finished:
        return None
    try:
        delta = datetime.fromisoformat(finished) - datetime.fromisoformat(started)
    except ValueError:
        return None
    secs = delta.total_seconds()
    return secs if secs >= 0 else None


class JobStore:
    """Owns the on-disk state of the single cozy generation job.

    state.json + output.png live in state_dir. Writes are atomic
    (temp + os.replace). Modeled on anix-upgrade-ui/run_store.py.
    """

    def __init__(self, state_dir, client):
        os.makedirs(state_dir, exist_ok=True)
        self.state_dir = state_dir
        self.state_path = os.path.join(state_dir, "state.json")
        self.image_path = os.path.join(state_dir, "output.png")
        self.client = client
        self._lock = threading.RLock()
        self._thread = None

    # -- state.json ----------------------------------------------------------

    def _default_state(self):
        return {"workflow": None, "prompt": "", "width": DEFAULT_W,
                "height": DEFAULT_H, "image": "", "job": _idle_job(),
                "output": os.path.exists(self.image_path)}

    def _read_raw(self):
        try:
            with open(self.state_path) as f:
                # Merge onto defaults so state files written by an older cozy
                # (missing newly-added keys like "image") still carry every
                # field the app/template expects.
                return {**self._default_state(), **json.load(f)}
        except (OSError, ValueError):
            return self._default_state()

    def _write_state(self, state):
        tmp = self.state_path + ".tmp"
        with open(tmp, "w") as f:
            json.dump(state, f)
        os.replace(tmp, self.state_path)

    def read_state(self):
        state = self._read_raw()
        state["output"] = os.path.exists(self.image_path)
        job = state.get("job", _idle_job())
        if job.get("status") != "running":
            return state
        if self._thread is not None and self._thread.is_alive():
            return state
        with self._lock:
            state = self._read_raw()
            job = state.get("job", _idle_job())
            if job.get("status") != "running":
                state["output"] = os.path.exists(self.image_path)
                return state
            finalized = False
            pid = job.get("prompt_id")
            if pid:
                try:
                    finalized = self._fetch_result(pid, state)
                except Exception:
                    finalized = False
            if not finalized:
                job.update(status="failed", finished_at=_now(), error="interrupted")
                state["job"] = job
            self._write_state(state)
            state["output"] = os.path.exists(self.image_path)
            return state

    # -- helpers -------------------------------------------------------------

    def _fetch_result(self, prompt_id, state):
        hist = self.client.history(prompt_id)
        entry = hist.get(prompt_id)
        if not entry:
            return False
        for _node_id, out in entry.get("outputs", {}).items():
            for img in out.get("images", []):
                data = self.client.view(
                    img["filename"], img.get("subfolder", ""), img.get("type", "output"))
                with open(self.image_path, "wb") as f:
                    f.write(data)
                state["job"].update(status="success", progress=100,
                                    finished_at=_now(), error=None)
                state["output"] = True
                return True
        return False

    # -- inputs --------------------------------------------------------------

    def set_inputs(self, workflow=None, prompt=None, width=None, height=None, image=None):
        with self._lock:
            state = self._read_raw()
            if workflow is not None:
                state["workflow"] = workflow
            if prompt is not None:
                state["prompt"] = prompt
            if width is not None:
                state["width"] = int(width)
            if height is not None:
                state["height"] = int(height)
            if image is not None:
                state["image"] = image
            self._write_state(state)

    # -- running -------------------------------------------------------------

    def start(self, workflow_name, workflow_path, prompt, width, height, image=""):
        with self._lock:
            # Check raw state first: if the persisted state says running,
            # reject regardless of thread liveness (conservative guard).
            # Orphan finalization is deferred to read_state() callers (UI).
            if self._read_raw().get("job", {}).get("status") == "running":
                return False
            # load_and_patch may snap dimensions to a model's resolution buckets;
            # store the effective size so the UI shows what was actually used.
            graph, width, height = workflows.load_and_patch(
                workflow_path, prompt, width, height, image=image)
            client_id = uuid.uuid4().hex
            state = self._read_raw()
            state.update(workflow=workflow_name, prompt=prompt,
                         width=int(width), height=int(height), image=image)
            state["job"] = {"status": "running", "prompt_id": None, "progress": 0,
                            "started_at": _now(), "finished_at": None,
                            "error": None, "client_id": client_id}
            try:
                os.remove(self.image_path)
            except OSError:
                pass
            state["output"] = False
            self._write_state(state)
            self._thread = threading.Thread(
                target=self._run, args=(graph, client_id), daemon=True)
            self._thread.start()
            return True

    def _set_progress(self, pct):
        with self._lock:
            state = self._read_raw()
            if state.get("job", {}).get("status") == "running":
                state["job"]["progress"] = pct
                self._write_state(state)

    def _fail(self, error):
        with self._lock:
            state = self._read_raw()
            state["job"].update(status="failed", finished_at=_now(), error=error)
            self._write_state(state)

    def _run(self, graph, client_id):
        events = None
        try:
            # Free models/memory from any previous job so this one starts from a
            # clean pool; on unified-memory devices back-to-back jobs OOM otherwise.
            self.client.free()
            events = self.client.connect_events(client_id)
            prompt_id = self.client.submit(graph, client_id)
            with self._lock:
                state = self._read_raw()
                state["job"]["prompt_id"] = prompt_id
                self._write_state(state)
            while True:
                msg = events.recv()
                mtype = msg.get("type")
                data = msg.get("data", {}) or {}
                if mtype == "progress":
                    mx = data.get("max") or 0
                    val = data.get("value") or 0
                    self._set_progress(int(val * 100 / mx) if mx else 0)
                elif mtype == "execution_error" and data.get("prompt_id") == prompt_id:
                    self._fail(str(data.get("exception_message", "execution error")))
                    return
                elif mtype == "executing" and data.get("node") is None \
                        and data.get("prompt_id") == prompt_id:
                    break
                elif mtype == "execution_success" and data.get("prompt_id") == prompt_id:
                    break
            # ComfyUI emits execution_success over the websocket slightly before
            # /history is queryable; on slow machines a single fetch loses that
            # race. Retry briefly before declaring no output.
            finalized = False
            for _ in range(20):
                with self._lock:
                    state = self._read_raw()
                    if self._fetch_result(prompt_id, state):
                        self._write_state(state)
                        finalized = True
                        break
                time.sleep(0.5)
            if not finalized:
                with self._lock:
                    state = self._read_raw()
                    state["job"].update(status="failed", finished_at=_now(),
                                        error="no output image")
                    self._write_state(state)
        except Exception as e:  # noqa: BLE001 - surface any failure to the UI
            self._fail(str(e))
        finally:
            if events is not None:
                events.close()

    # -- clear ---------------------------------------------------------------

    def clear(self):
        with self._lock:
            try:
                os.remove(self.image_path)
            except OSError:
                pass
            state = self._read_raw()
            state["prompt"] = ""
            state["image"] = ""
            state["job"] = _idle_job()
            state["output"] = False
            self._write_state(state)
