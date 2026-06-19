import json
import os
import subprocess
import threading
import time
from datetime import datetime, timezone

REPLAY_CAP_BYTES = 512 * 1024
POLL_INTERVAL_S = 0.5


def _now():
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def _sse(msg):
    return f"data: {msg}\n\n"


class RunStore:
    """Owns the on-disk state of a single background job: a log file and a state JSON.

    The subprocess writes directly to the log file descriptor, so no pipe exists
    between the UI and the job — nothing can block if viewers disconnect or the
    UI process restarts.
    """

    def __init__(self, state_dir, label="JOB"):
        os.makedirs(state_dir, exist_ok=True)
        self.log_path = os.path.join(state_dir, "current.log")
        self.state_path = os.path.join(state_dir, "state.json")
        self.label = label
        self._lock = threading.RLock()
        self._thread = None

    # -- state.json ----------------------------------------------------------

    def _read_raw(self):
        try:
            with open(self.state_path) as f:
                return json.load(f)
        except (OSError, ValueError):
            return {"status": "idle"}

    def _write_state(self, state):
        tmp = self.state_path + ".tmp"
        with open(tmp, "w") as f:
            json.dump(state, f)
        os.replace(tmp, self.state_path)

    @staticmethod
    def _pid_alive(pid):
        if not pid:
            return False
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            return False
        except PermissionError:
            return True
        return True

    def read_state(self):
        """Current state, finalizing orphaned runs.

        A run is orphaned when state.json says running but no runner thread
        exists (UI was restarted) and the recorded PID is dead.
        """
        state = self._read_raw()
        if state.get("status") != "running":
            return state
        if self._thread is not None and self._thread.is_alive():
            return state
        if self._pid_alive(state.get("pid")):
            return state
        with self._lock:
            state = self._read_raw()
            if state.get("status") != "running":
                return state
            state.update(status="failed", returncode=None, finished_at=_now())
            self._write_state(state)
            return state

    # -- running -------------------------------------------------------------

    def start(self, cmd, env=None):
        """Begin a run in a background thread. Returns False if one is already active."""
        with self._lock:
            if self.read_state().get("status") == "running":
                return False
            state = {
                "status": "running",
                "pid": None,
                "cmd": cmd,
                "started_at": _now(),
                "finished_at": None,
                "returncode": None,
            }
            with open(self.log_path, "wb") as log_fd:
                try:
                    proc = subprocess.Popen(
                        cmd, stdout=log_fd, stderr=subprocess.STDOUT, env=env
                    )
                except OSError as e:
                    log_fd.write(f"[ERROR: {e}]\n".encode())
                    state.update(status="failed", finished_at=_now())
                    self._write_state(state)
                    return True
            state["pid"] = proc.pid
            self._write_state(state)
            self._thread = threading.Thread(
                target=self._wait, args=(proc,), daemon=True
            )
            self._thread.start()
            return True

    def _wait(self, proc):
        rc = proc.wait()
        with self._lock:
            state = self._read_raw()
            state.update(
                status="success" if rc == 0 else "failed",
                returncode=rc,
                finished_at=_now(),
            )
            self._write_state(state)

    # -- streaming -----------------------------------------------------------

    def stream(self):
        """SSE generator: replay capped log tail, then follow until the run
        leaves 'running'. Safe for any number of concurrent consumers."""
        pos = 0
        try:
            size = os.path.getsize(self.log_path)
            if size > REPLAY_CAP_BYTES:
                pos = size - REPLAY_CAP_BYTES
        except OSError:
            pass
        drop_partial = pos > 0
        buf = b""
        while True:
            try:
                size = os.path.getsize(self.log_path)
            except OSError:
                size = 0
            if size < pos:  # log truncated by a new run starting
                pos, buf, drop_partial = 0, b"", False
            if size > pos:
                with open(self.log_path, "rb") as f:
                    f.seek(pos)
                    data = f.read()
                    pos = f.tell()
                buf += data
                lines = buf.split(b"\n")
                buf = lines.pop()
                if drop_partial:
                    lines = lines[1:]
                    drop_partial = False
                for line in lines:
                    yield _sse(line.decode("utf-8", errors="replace"))
                continue
            state = self.read_state()
            if state.get("status") == "running":
                time.sleep(POLL_INTERVAL_S)
                continue
            if buf:
                yield _sse(buf.decode("utf-8", errors="replace"))
            status = state.get("status", "idle")
            if status == "success":
                yield _sse(f"[{self.label} SUCCESSFUL]")
            elif status == "failed":
                yield _sse(f"[{self.label} FAILED (exit {state.get('returncode')})]")
            else:
                yield _sse(f"[no {self.label.lower()} output]")
            yield _sse("[DONE]")
            return
