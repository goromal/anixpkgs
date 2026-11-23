"""The generation operations behind the CLI. Backend choice lives here, in
config.backends, so agents ask for a task ("edit this image") and never name
a model."""
import os
import sys
import tempfile

from PIL import Image

from . import workflows
from .comfy import ComfyClient
from .cozy import CozyClient

MESH_PROMPT_SUFFIX = (", a single complete object, centered, entire object in frame, "
                      "plain white background, soft even studio lighting, no cast shadows, "
                      "three-quarter view")


def _progress(stage, value, eta):
    if not sys.stderr.isatty():
        return
    if stage == "queued":
        msg = "queued (position %s)" % value
    elif stage == "elapsed":
        msg = "running, %ds elapsed" % value
    else:
        msg = "running %d%%" % (value or 0)
    if eta:
        msg += ", ~%ds left" % eta
    sys.stderr.write("\r\033[K" + msg)
    sys.stderr.flush()


def _done():
    if sys.stderr.isatty():
        sys.stderr.write("\r\033[K")


def _target(project, out, label, ext):
    if out:
        return os.path.abspath(out)
    if project:
        return project.next_output(label, ext)
    return os.path.abspath("%s.%s" % (label, ext))


def cozy_client(cfg):
    return CozyClient(cfg.cozy_url, token_file=cfg.cozy_token_file,
                      input_dir=cfg.path("cozy_input_dir"))


def image_gen(cfg, prompt, width=1024, height=1024, out=None, project=None,
              backend=None):
    wf = backend or cfg.backends["image"]
    dest = _target(project, out, prompt, "png")
    cozy_client(cfg).run({"workflow": wf, "prompt": prompt, "width": width,
                          "height": height, "basename": "aiart"}, dest, _progress)
    _done()
    if project:
        project.record("image.gen", dest, prompt=prompt, backend=wf,
                       width=width, height=height)
    return dest


def image_edit(cfg, image, prompt, rect=None, out=None, project=None, backend=None):
    wf = backend or cfg.backends["edit"]
    client = cozy_client(cfg)
    staged = client.stage_input(image)
    job = {"workflow": wf, "prompt": prompt, "image": staged, "basename": "aiart"}
    if rect:
        job["rect"] = rect
    dest = _target(project, out, prompt, "png")
    client.run(job, dest, _progress)
    _done()
    if project:
        project.record("image.edit", dest, prompt=prompt, backend=wf,
                       source=os.path.abspath(image), rect=rect)
    return dest


def flatten(image_path, dest):
    """Composite transparency onto white: ComfyUI's LoadImage drops alpha, and
    the mesh models read transparent-black as part of the object."""
    with Image.open(image_path) as im:
        if im.mode in ("RGBA", "LA") or (im.mode == "P" and "transparency" in im.info):
            rgba = im.convert("RGBA")
            bg = Image.new("RGBA", rgba.size, (255, 255, 255, 255))
            bg.alpha_composite(rgba)
            bg.convert("RGB").save(dest)
        else:
            im.convert("RGB").save(dest)
    return dest


def mesh_gen(cfg, image=None, prompt=None, out=None, project=None, backend=None,
             params=None):
    if not image and not prompt:
        raise ValueError("give an image, a prompt, or both")
    name = backend or cfg.backends["mesh"]
    meta, graph = workflows.load(name, cfg.workflow_dirs)
    missing = workflows.missing_models(meta, cfg.path("comfy_models_dir"))
    if missing:
        raise workflows.WorkflowError(
            "%s needs models that are not downloaded: %s (run `aiart models pull`)"
            % (name, ", ".join(m["name"] for m in missing)))
    label = prompt or os.path.splitext(os.path.basename(image))[0]
    source = image
    if not image:
        source = image_gen(cfg, prompt + MESH_PROMPT_SUFFIX, 1024, 1024,
                           project=project)
    comfy = ComfyClient(cfg.comfy_url)
    with tempfile.TemporaryDirectory() as tmp:
        flat = flatten(source, os.path.join(tmp, "aiart-mesh-input.png"))
        staged = comfy.upload_image(flat)
    g, applied = workflows.patch(meta, graph, staged, "aiart/mesh", params)
    comfy.free()
    outputs = comfy.wait(comfy.submit(g), on_progress=_progress)
    _done()
    items = outputs.get(meta["save_node"], {}).get("3d") or []
    if not items:
        raise workflows.WorkflowError("workflow finished without a 3D output")
    dest = _target(project, out, label, "glb")
    comfy.fetch(items[0], dest)
    if project:
        project.record("mesh.gen", dest, backend=name, prompt=prompt,
                       source=os.path.abspath(source), params=applied)
    return dest
