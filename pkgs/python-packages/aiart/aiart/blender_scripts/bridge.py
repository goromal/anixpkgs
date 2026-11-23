"""aiart live bridge, run inside an interactive Blender (`blender --python`).

Listens on 127.0.0.1 and runs each request on Blender's main thread through a
timer, because bpy is not thread-safe. Requests are one JSON line:
{"token", "op", ...}; replies are one JSON line {"ok", "result"|"error",
"stdout"}. The port and a per-session token go into AIART_BRIDGE_STATE so
only processes that can read that 0600 file can drive this Blender.

ops: ping | exec {code} | screenshot {path}
`exec` runs `code` with `bpy` and `mathutils` in scope; whatever it assigns
to `result` (JSON-serialisable) is returned.
"""
import contextlib
import io
import json
import os
import queue
import secrets
import socket
import threading
import traceback

import bpy
import mathutils

STATE = os.environ.get("AIART_BRIDGE_STATE") or os.path.join(
    os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "aiart-blender.json")
TOKEN = secrets.token_hex(16)
_requests = queue.Queue()


def _view3d():
    for window in bpy.context.window_manager.windows:
        for area in window.screen.areas:
            if area.type == "VIEW_3D":
                return window, area
    return None, None


def _exec(req):
    scope = {"bpy": bpy, "mathutils": mathutils, "result": None}
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        exec(compile(req["code"], "<aiart>", "exec"), scope)
    return scope["result"], out.getvalue()


def _screenshot(req):
    window, area = _view3d()
    if area is None:
        raise RuntimeError("no 3D viewport open")
    path = os.path.abspath(req["path"])
    with bpy.context.temp_override(window=window, area=area):
        bpy.ops.screen.screenshot_area(filepath=path)
    return path, ""


OPS = {
    "ping": lambda req: ({"blender": bpy.app.version_string,
                          "file": bpy.data.filepath}, ""),
    "exec": _exec,
    "screenshot": _screenshot,
}


def _drain():
    while True:
        try:
            req, reply = _requests.get_nowait()
        except queue.Empty:
            return 0.1
        try:
            result, stdout = OPS[req["op"]](req)
            reply.update(ok=True, result=result, stdout=stdout)
        except Exception:  # noqa: BLE001 - reported to the caller
            reply.update(ok=False, error=traceback.format_exc())
        reply["_done"].set()


def _handle(conn):
    with conn, conn.makefile("rwb") as f:
        try:
            req = json.loads(f.readline())
        except ValueError:
            return
        if req.get("token") != TOKEN:
            reply = {"ok": False, "error": "bad token"}
        elif req.get("op") not in OPS:
            reply = {"ok": False, "error": "unknown op %r" % req.get("op")}
        else:
            reply = {"_done": threading.Event()}
            _requests.put((req, reply))
            reply["_done"].wait()
            del reply["_done"]
        try:
            f.write((json.dumps(reply, default=str) + "\n").encode())
            f.flush()
        except OSError:
            pass


def _serve(sock):
    while True:
        conn, _ = sock.accept()
        threading.Thread(target=_handle, args=(conn,), daemon=True).start()


def start():
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind(("127.0.0.1", int(os.environ.get("AIART_BRIDGE_PORT", "0"))))
    sock.listen()
    port = sock.getsockname()[1]
    fd = os.open(STATE, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump({"port": port, "token": TOKEN, "pid": os.getpid()}, f)
    threading.Thread(target=_serve, args=(sock,), daemon=True).start()
    bpy.app.timers.register(_drain, persistent=True)
    load = os.environ.get("AIART_BRIDGE_IMPORT")
    if load:
        def _import():
            bpy.ops.import_scene.gltf(filepath=load)
        bpy.app.timers.register(_import, first_interval=0.5)
    print("aiart bridge listening on 127.0.0.1:%d" % port)


start()
