"""Headless review renders: blender -b -P render_views.py -- MODEL OUTDIR VIEWS ENGINE SIZE

MODEL is a .glb/.gltf (imported into an empty scene) or a .blend (opened).
Each view is framed on the bounding box of all meshes and written as
OUTDIR/<view>.png. VIEWS is comma-separated from: front, back, left, right,
top, iso, iso_back.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
model, outdir, views, engine, size = argv[0], argv[1], argv[2].split(","), argv[3], int(argv[4])
outdir = os.path.abspath(outdir)
os.makedirs(outdir, exist_ok=True)

if model.endswith(".blend"):
    bpy.ops.wm.open_mainfile(filepath=model)
else:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=model)

scene = bpy.context.scene
meshes = [o for o in scene.objects if o.type == "MESH" and o.visible_get()]
if not meshes:
    sys.exit("no visible meshes in " + model)
corners = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
lo = Vector([min(c[i] for c in corners) for i in range(3)])
hi = Vector([max(c[i] for c in corners) for i in range(3)])
center = (lo + hi) / 2
radius = max((hi - lo).length / 2, 1e-3)

DIRS = {
    "front": (0, -1, 0), "back": (0, 1, 0), "left": (-1, 0, 0),
    "right": (1, 0, 0), "top": (0, 0, 1), "iso": (1, -1, 0.8),
    "iso_back": (-1, 1, 0.8),
}

cam_data = bpy.data.cameras.new("aiart_cam")
cam_data.lens = 50
cam_data.clip_end = radius * 100
cam = bpy.data.objects.new("aiart_cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam

if not any(o.type == "LIGHT" for o in scene.objects):
    for name, energy, d in (("key", 4.0, (1, -1, 1.5)), ("fill", 1.5, (-1.2, -0.6, 0.5)),
                            ("rim", 2.5, (0, 1.2, 1))):
        ld = bpy.data.lights.new(name, "SUN")
        ld.energy = energy
        lo_ = bpy.data.objects.new(name, ld)
        lo_.rotation_euler = (-Vector(d)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(lo_)
if scene.world is None:
    scene.world = bpy.data.worlds.new("aiart_world")
scene.world.color = (0.05, 0.05, 0.06)

ENGINES = {"eevee": ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"), "cycles": ("CYCLES",),
           "workbench": ("BLENDER_WORKBENCH",)}
for ident in ENGINES[engine]:
    try:
        scene.render.engine = ident
        break
    except TypeError:
        continue
if engine == "cycles":
    scene.cycles.samples = 48
    prefs = bpy.context.preferences.addons["cycles"].preferences
    prefs.compute_device_type = "CUDA"
    prefs.get_devices()
    scene.cycles.device = "GPU"
if engine == "workbench":
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
scene.render.resolution_x = scene.render.resolution_y = size
scene.render.film_transparent = False

fov = cam_data.angle
dist = radius / math.sin(fov / 2) * 1.1
for view in views:
    d = Vector(DIRS[view]).normalized()
    cam.location = center + d * dist
    if view == "top":
        cam.rotation_euler = (0.0, 0.0, 0.0)
    else:
        cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(outdir, view + ".png")
    bpy.ops.render.render(write_still=True)
    print("wrote", scene.render.filepath)
