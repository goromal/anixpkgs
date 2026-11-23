"""Client side of the Blender live bridge, plus headless helpers."""
import json
import os
import socket
import subprocess

SCRIPTS = os.path.join(os.path.dirname(__file__), "blender_scripts")
VIEWS = ("front", "back", "left", "right", "top", "iso", "iso_back")


class BlenderError(Exception):
    pass


def state_path():
    return os.environ.get("AIART_BRIDGE_STATE") or os.path.join(
        os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "aiart-blender.json")


def _state():
    try:
        with open(state_path()) as f:
            return json.load(f)
    except (OSError, ValueError):
        raise BlenderError("no live Blender: start one with `aiart blender open`")


def call(op, timeout=600, **fields):
    st = _state()
    try:
        sock = socket.create_connection(("127.0.0.1", st["port"]), timeout=timeout)
    except OSError:
        raise BlenderError("live Blender (pid %s) is not answering; "
                           "restart it with `aiart blender open`" % st.get("pid"))
    with sock, sock.makefile("rwb") as f:
        f.write((json.dumps({"token": st["token"], "op": op, **fields}) + "\n").encode())
        f.flush()
        line = f.readline()
    if not line:
        raise BlenderError("Blender closed the connection")
    reply = json.loads(line)
    if not reply.get("ok"):
        raise BlenderError(reply.get("error", "unknown bridge error"))
    return reply


def exec_code(code):
    return call("exec", code=code)


def open_gui(blender, path=None, log=None):
    """Start an interactive Blender with the bridge, detached from this shell."""
    env = dict(os.environ)
    env["AIART_BRIDGE_STATE"] = state_path()
    args = [blender]
    if path and path.endswith(".blend"):
        args.append(path)
    elif path:
        env["AIART_BRIDGE_IMPORT"] = os.path.abspath(path)
    args += ["--python", os.path.join(SCRIPTS, "bridge.py")]
    out = open(log or os.devnull, "ab")
    proc = subprocess.Popen(args, env=env, stdout=out, stderr=subprocess.STDOUT,
                            stdin=subprocess.DEVNULL, start_new_session=True)
    return proc.pid


def render(blender, model, outdir, views=("front", "iso", "top"), engine="eevee",
           size=768):
    bad = [v for v in views if v not in VIEWS]
    if bad:
        raise BlenderError("unknown views %s; choose from %s" % (bad, ", ".join(VIEWS)))
    cmd = [blender, "-b", "--factory-startup", "-P",
           os.path.join(SCRIPTS, "render_views.py"), "--",
           os.path.abspath(model), outdir, ",".join(views), engine, str(size)]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        raise BlenderError("render failed:\n" + (r.stdout + r.stderr)[-3000:])
    return [os.path.join(os.path.abspath(outdir), v + ".png") for v in views]


def import_code(path):
    return ("import bpy\nbefore=set(bpy.data.objects)\n"
            "bpy.ops.import_scene.gltf(filepath=%r)\n"
            "result=[o.name for o in bpy.data.objects if o not in before]\n" % os.path.abspath(path))


def save_code(path=None):
    if path:
        return "import bpy\nbpy.ops.wm.save_as_mainfile(filepath=%r)\nresult=bpy.data.filepath\n" % os.path.abspath(path)
    return "import bpy\nbpy.ops.wm.save_mainfile()\nresult=bpy.data.filepath\n"


def export_code(path, selected=False):
    return ("import bpy\nbpy.ops.export_scene.gltf(filepath=%r, export_format='GLB', use_selection=%r)\n"
            "result=%r\n" % (os.path.abspath(path), selected, os.path.abspath(path)))


SCENE_CODE = """import bpy
result = {"file": bpy.data.filepath, "objects": [
    {"name": o.name, "type": o.type, "location": list(o.location),
     "dimensions": list(o.dimensions),
     "verts": len(o.data.vertices) if o.type == "MESH" else None,
     "materials": [m.name for m in getattr(o.data, "materials", []) if m]}
    for o in bpy.context.scene.objects]}
"""
