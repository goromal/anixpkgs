"""aiart command line. With no command it opens the TUI.

Generation commands print the path of what they wrote on stdout (and nothing
else), so an agent can chain them; progress goes to stderr.
"""
import argparse
import json
import os
import subprocess
import sys

from . import blender, config, models, ops, projects, workflows
from .comfy import ComfyError
from .cozy import CozyError

ERRORS = (CozyError, ComfyError, blender.BlenderError, workflows.WorkflowError,
          projects.ProjectError, ValueError, OSError)


def _project(args):
    return None if getattr(args, "no_project", False) else projects.find()


def _rect(text):
    try:
        x, y, w, h = (int(v) for v in text.split(","))
    except ValueError:
        raise argparse.ArgumentTypeError("rect is x,y,w,h in pixels")
    return {"x": x, "y": y, "w": w, "h": h}


def _param(text):
    key, sep, value = text.partition("=")
    if not sep:
        raise argparse.ArgumentTypeError("use key=value")
    try:
        return key, json.loads(value)
    except ValueError:
        return key, value


def _emit(value):
    if isinstance(value, (dict, list)):
        print(json.dumps(value, indent=2))
    elif value is not None:
        print(value)


def cmd_status(cfg, args):
    rows = {"config": os.environ.get("AIART_CONFIG") or config.DEFAULT_PATH,
            "projects_dir": cfg.path("projects_dir"), "backends": cfg.backends}
    try:
        ops.cozy_client(cfg).status()
        rows["cozy"] = "ok " + cfg.cozy_url
    except CozyError as e:
        rows["cozy"] = "DOWN: %s" % e
    try:
        import requests
        stats = requests.get(cfg.comfy_url + "/system_stats", timeout=5).json()
        dev = (stats.get("devices") or [{}])[0]
        rows["comfyui"] = "ok %s, %s, %.1f/%.1f GB VRAM free" % (
            stats["system"].get("comfyui_version"), dev.get("name", "?"),
            dev.get("vram_free", 0) / 1e9, dev.get("vram_total", 0) / 1e9)
    except Exception as e:  # noqa: BLE001 - status is best effort
        rows["comfyui"] = "DOWN: %s" % e
    mesh = {}
    for name in workflows.available(cfg.workflow_dirs):
        meta, _ = workflows.load(name, cfg.workflow_dirs)
        missing = workflows.missing_models(meta, cfg.path("comfy_models_dir"))
        mesh[name] = {"title": meta.get("title"), "min_vram_gb": meta.get("min_vram_gb"),
                      "models": "missing: " + ", ".join(m["name"] for m in missing)
                      if missing else "ready"}
    rows["mesh_workflows"] = mesh
    try:
        rows["blender_live"] = blender.call("ping", timeout=3)["result"]
    except blender.BlenderError as e:
        rows["blender_live"] = str(e)
    p = projects.find()
    if p:
        rows["project"] = {"name": p.name, "kind": p.kind, "root": p.root}
    _emit(rows)


def cmd_project(cfg, args):
    if args.action == "new":
        p = projects.create(cfg.projects_dir, args.name, args.kind, args.description)
        _emit(p.root)
    elif args.action == "list":
        _emit([{"name": p.name, "kind": p.kind, "root": p.root}
               for p in projects.list_projects(cfg.projects_dir)])
    else:
        p = projects.find()
        if not p:
            raise projects.ProjectError("not inside an aiart project")
        _emit({**p.meta, "root": p.root, "journal": p.journal()[-args.tail:]})


def cmd_image(cfg, args):
    p = _project(args)
    if args.action == "gen":
        _emit(ops.image_gen(cfg, args.prompt, args.width, args.height, args.out, p,
                            args.backend))
    else:
        _emit(ops.image_edit(cfg, args.image, args.prompt, args.rect, args.out, p,
                             args.backend))


def cmd_mesh(cfg, args):
    _emit(ops.mesh_gen(cfg, args.image, args.prompt, args.out, _project(args),
                       args.backend, dict(args.set or [])))


def cmd_models(cfg, args):
    if args.action == "list":
        names = list(workflows.available(cfg.workflow_dirs))
    else:
        names = [args.workflow or cfg.backends["mesh"]]
    for name in names:
        meta, _ = workflows.load(name, cfg.workflow_dirs)
        missing = workflows.missing_models(meta, cfg.path("comfy_models_dir"))
        if args.action == "list":
            print("%-16s %-50s %s" % (name, meta.get("title", ""),
                                      "missing %d" % len(missing) if missing else "ready"))
            continue
        for m in missing:
            _emit(models.pull(m, cfg.path("comfy_models_dir")))


def cmd_blender(cfg, args):
    a = args.action
    if a == "open":
        log = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "aiart-blender.log")
        pid = blender.open_gui(cfg.blender, args.path, log)
        _emit("Blender started (pid %d); log %s" % (pid, log))
        return
    if a == "render":
        outdir = args.outdir or os.path.splitext(os.path.abspath(args.model))[0] + "-views"
        for path in blender.render(cfg.blender, args.model, outdir, args.views.split(","),
                                   args.engine, args.size):
            _emit(path)
        return
    if a == "ping":
        reply = blender.call("ping")
    elif a == "scene":
        reply = blender.exec_code(blender.SCENE_CODE)
    elif a == "exec":
        code = sys.stdin.read() if args.file == "-" else open(args.file).read()
        reply = blender.exec_code(code)
    elif a == "import":
        reply = blender.exec_code(blender.import_code(args.path))
    elif a == "save":
        reply = blender.exec_code(blender.save_code(args.path))
    elif a == "export":
        reply = blender.exec_code(blender.export_code(args.path, args.selected))
    elif a == "screenshot":
        reply = blender.call("screenshot", path=args.path)
    if reply.get("stdout"):
        sys.stderr.write(reply["stdout"])
    _emit(reply.get("result"))


def cmd_view(cfg, args):
    path = args.path
    if not path:
        p = projects.find()
        if not p:
            raise projects.ProjectError("give a path or run inside a project")
        path = os.path.join(p.root, "latest.png")
    subprocess.Popen([cfg.image_viewer, path], start_new_session=True,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def cmd_tui(cfg, args):
    from .tui import run
    run(cfg)


def build_parser():
    ap = argparse.ArgumentParser(prog="aiart", description=__doc__.splitlines()[0])
    sub = ap.add_subparsers(dest="cmd")

    sub.add_parser("tui", help="project picker that launches agents (default)")
    sub.add_parser("status", help="backends, services and live Blender as JSON")

    pp = sub.add_parser("project", help="create, list or describe projects")
    ps = pp.add_subparsers(dest="action", required=True)
    pn = ps.add_parser("new")
    pn.add_argument("name")
    pn.add_argument("--kind", choices=projects.KINDS, required=True)
    pn.add_argument("--description", default="")
    ps.add_parser("list")
    pi = ps.add_parser("info", help="current project and recent journal")
    pi.add_argument("--tail", type=int, default=20)

    ip = sub.add_parser("image", help="2D generation and editing")
    isub = ip.add_subparsers(dest="action", required=True)
    ig = isub.add_parser("gen", help="text to image")
    ig.add_argument("prompt")
    ig.add_argument("--width", type=int, default=1024)
    ig.add_argument("--height", type=int, default=1024)
    ie = isub.add_parser("edit", help="edit an image (annotated screenshots welcome)")
    ie.add_argument("image")
    ie.add_argument("prompt")
    ie.add_argument("--rect", type=_rect, help="x,y,w,h region to edit")
    for p in (ig, ie):
        p.add_argument("--out")
        p.add_argument("--backend", help="override the configured cozy workflow")
        p.add_argument("--no-project", action="store_true")

    mp = sub.add_parser("mesh", help="3D generation")
    msub = mp.add_subparsers(dest="action", required=True)
    mg = msub.add_parser("gen", help="image and/or prompt to GLB")
    mg.add_argument("--image")
    mg.add_argument("--prompt")
    mg.add_argument("--out")
    mg.add_argument("--backend", help="override the configured mesh workflow")
    mg.add_argument("--set", type=_param, action="append", metavar="KEY=VALUE",
                    help="workflow tunable (see `aiart status`), e.g. steps=40")
    mg.add_argument("--no-project", action="store_true")

    dp = sub.add_parser("models", help="model weights for mesh workflows")
    dsub = dp.add_subparsers(dest="action", required=True)
    dsub.add_parser("list")
    dl = dsub.add_parser("pull")
    dl.add_argument("workflow", nargs="?")

    bp = sub.add_parser("blender", help="live Blender bridge and headless renders")
    bsub = bp.add_subparsers(dest="action", required=True)
    bo = bsub.add_parser("open", help="start Blender with the bridge")
    bo.add_argument("path", nargs="?", help=".blend to open or .glb to import")
    bsub.add_parser("ping")
    bsub.add_parser("scene", help="objects in the live scene as JSON")
    be = bsub.add_parser("exec", help="run a Python file ('-' for stdin) in Blender")
    be.add_argument("file")
    bi = bsub.add_parser("import")
    bi.add_argument("path")
    bs = bsub.add_parser("save")
    bs.add_argument("path", nargs="?")
    bx = bsub.add_parser("export", help="export the scene as GLB")
    bx.add_argument("path")
    bx.add_argument("--selected", action="store_true")
    bsh = bsub.add_parser("screenshot", help="capture the live 3D viewport")
    bsh.add_argument("path")
    br = bsub.add_parser("render", help="headless review renders of a model")
    br.add_argument("model")
    br.add_argument("--views", default="front,iso,top",
                    help="comma list of %s" % ",".join(blender.VIEWS))
    br.add_argument("--engine", choices=("eevee", "cycles", "workbench"), default="eevee")
    br.add_argument("--size", type=int, default=768)
    br.add_argument("--outdir")

    vp = sub.add_parser("view", help="open an image in the viewer (default latest.png)")
    vp.add_argument("path", nargs="?")
    return ap


COMMANDS = {"tui": cmd_tui, "status": cmd_status, "project": cmd_project,
            "image": cmd_image, "mesh": cmd_mesh, "models": cmd_models,
            "blender": cmd_blender, "view": cmd_view}


def main(argv=None):
    args = build_parser().parse_args(argv)
    cfg = config.load()
    try:
        COMMANDS[args.cmd or "tui"](cfg, args)
    except ERRORS as e:
        sys.stderr.write("aiart: %s\n" % e)
        return 1
    except KeyboardInterrupt:
        return 130
    return 0


if __name__ == "__main__":
    sys.exit(main())
