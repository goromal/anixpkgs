# End-to-end check inside Blender against a fake tile server (no network):
#   blender -b --factory-startup --python e2e_blender.py -- <scripts/addons dir>
# Two 50 m square tiles sit at ECEF-scale offsets, one 30 m above the target and
# one 300 m east; with a 100 m radius only the first should survive the crop.
# The squares' local axes are ECEF-aligned (like real tiles), so they appear
# tilted in ENU; check centroid and edge lengths rather than extents.
import io
import json
import os
import sys
import tempfile
import time
import urllib.parse

sys.path.insert(0, sys.argv[sys.argv.index("--") + 1])

import bpy  # noqa: E402

from earth_tiles import scene, tiles  # noqa: E402

# A blender-earth wrapper preloads its own installed copy; make sure we test this one.
assert scene.__file__.startswith(os.path.abspath(sys.path[0])), scene.__file__

LAT, LON = 40.748440, -73.985664


def square_glb(path):
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)
    bpy.ops.mesh.primitive_plane_add(size=50.0)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True)
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)
    with open(path, "rb") as f:
        return f.read()


def placed(glb, ecef, credit):
    doc, rest = tiles.read_glb(glb)
    doc["asset"]["copyright"] = credit
    doc["nodes"][doc["scenes"][0]["nodes"][0]]["translation"] = [ecef[0], ecef[2], -ecef[1]]
    return tiles.write_glb(doc, rest)


class Resp(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


def main():
    tmp = tempfile.mkdtemp()
    base = square_glb(os.path.join(tmp, "sq.glb"))
    enu = tiles.ecef_to_enu_matrix(LAT, LON)
    p0 = tiles.lla_to_ecef(LAT, LON, 30.0)
    p1 = [a + 300.0 * e for a, e in zip(p0, enu[0][:3])]
    c = tiles.lla_to_ecef(LAT, LON)
    box = c + [x * 1000.0 for x in enu[0][:3] + enu[1][:3] + enu[2][:3]]
    routes = {
        "/v1/3dtiles/root.json": json.dumps(
            {
                "root": {
                    "boundingVolume": {"box": box},
                    "geometricError": 1.0,
                    "children": [
                        {"boundingVolume": {"box": box}, "geometricError": 1.0, "content": {"uri": "a.glb?session=S"}},
                        {"boundingVolume": {"box": box}, "geometricError": 1.0, "content": {"uri": "b.glb"}},
                    ],
                }
            }
        ).encode(),
        "/v1/3dtiles/a.glb": placed(base, p0, "Data A"),
        "/v1/3dtiles/b.glb": placed(base, p1, "Data A;Data B"),
    }

    hang = {"glb": False}

    def opener(url, timeout=None):
        path = urllib.parse.urlparse(url).path
        if hang["glb"] and path.endswith(".glb"):
            time.sleep(3.0)  # an unanswered request
        return Resp(routes[path])

    real_client = tiles.Client
    tiles.Client = lambda key, **kw: real_client(key, opener=opener, **kw)
    os.environ[tiles.KEY_ENV] = "K"

    out = os.path.join(tmp, "out.glb")
    obj, credit = scene.generate(LAT, LON, radius=100.0, max_error=4.0, output=out)

    assert credit == "Data A; Data B", credit
    verts = [v.co for v in obj.data.vertices]
    assert len(verts) == 4, len(verts)
    cx = sum(v.x for v in verts) / 4.0
    cy = sum(v.y for v in verts) / 4.0
    assert abs(cx) < 1e-3 and abs(cy) < 1e-3, (cx, cy)
    assert abs(min(v.z for v in verts)) < 1e-6, [v.z for v in verts]
    for e in obj.data.edges:
        a, b = (obj.data.vertices[i].co for i in e.vertices)
        assert abs((a - b).length - 50.0) < 1e-3 or abs((a - b).length - 50.0 * 2**0.5) < 1e-3, (a - b).length
    with open(out, "rb") as f:
        doc, _ = tiles.read_glb(f.read())
    assert doc["asset"]["copyright"] == "Data A; Data B", doc["asset"]

    # Stepwise job, as the modal operator drives it: a zero budget imports one
    # tile per step, so the importing stage spans several steps.
    job = scene.ImportJob(LAT, LON, radius=100.0, max_error=4.0)
    job.start()
    importing_steps = 0
    while True:
        importing = job.stage == "importing"
        if job.step(budget=0.0):
            break
        importing_steps += importing
        time.sleep(0.01)
    assert job.error is None and job.stage == "done", job.status
    assert importing_steps >= 2, importing_steps

    # Cancelling mid-import removes everything the job added.
    n_objects, n_collections = len(bpy.data.objects), len(bpy.data.collections)
    job = scene.ImportJob(LAT, LON, radius=100.0, max_error=4.0)
    job.start()
    while not (job.stage == "importing" and job.done > 0):
        assert not job.step(budget=0.0), job.status
        time.sleep(0.01)
    assert len(bpy.data.objects) > n_objects
    job.cancel()
    while not job.step():
        time.sleep(0.01)
    assert isinstance(job.error, tiles.Cancelled), job.error
    assert (len(bpy.data.objects), len(bpy.data.collections)) == (n_objects, n_collections)
    assert job._tmp is None

    # Cancel while downloads hang: the job ends at once, and the worker removes
    # its temp dir when its in-flight requests return.
    hang["glb"] = True
    job = scene.ImportJob(LAT, LON, radius=100.0, max_error=4.0)
    job.start()
    while job.stage != "downloading":
        assert not job.step(), job.status
        time.sleep(0.01)
    while job._tmp is None:
        time.sleep(0.01)
    tmp = job._tmp
    job.cancel()
    t0 = time.monotonic()
    assert job.step(), job.status
    assert time.monotonic() - t0 < 0.5
    assert isinstance(job.error, tiles.Cancelled), job.error
    job._thread.join(timeout=10.0)
    assert not job._thread.is_alive()
    assert not os.path.exists(tmp), os.listdir(tmp)
    assert (len(bpy.data.objects), len(bpy.data.collections)) == (n_objects, n_collections)
    print("E2E OK")


try:
    main()
except Exception:
    import traceback

    traceback.print_exc()
    sys.exit(1)
sys.exit(0)
