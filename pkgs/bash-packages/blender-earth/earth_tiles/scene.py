"""Blender-side import, cleanup, and GLB export of selected tiles."""

import shutil
import tempfile
import threading
import time

import bmesh
import bpy
from mathutils import Matrix

from . import tiles


class ImportJob:
    """One area import, advanced by repeated step() calls on Blender's main thread.

    Tile selection and downloads run on a worker thread; step() imports a few
    tiles per call within a time budget so a modal operator can keep the UI
    responsive. generate() drives the same job in a blocking loop.
    """

    def __init__(
        self,
        lat,
        lon,
        radius=200.0,
        max_error=4.0,
        key="",
        key_file=tiles.DEFAULT_KEY_FILE,
        output="",
        crop=True,
        join=True,
        ground=True,
        draco=False,
        max_tiles=2000,
    ):
        self.lat, self.lon = lat, lon
        self.radius, self.max_error, self.max_tiles = radius, max_error, max_tiles
        self.output, self.crop, self.join, self.ground, self.draco = output, crop, join, ground, draco
        self._key = tiles.resolve_key(key, key_file)
        self.stage = "selecting"  # selecting, downloading, importing, finishing, done, failed
        self.done = 0
        self.total = 0
        self.error = None
        self.result = None
        self.credit = ""
        self._cancel = threading.Event()
        self._tmp = None
        self._paths = []
        self._coll = None
        self._meshes = []
        self._client = None
        self._last_log = 0.0
        self._thread = threading.Thread(target=self._fetch, name="earth-tiles-fetch", daemon=True)

    @property
    def status(self):
        if self.stage == "selecting":
            return f"Selecting tiles: {self.done} found"
        if self.stage in ("downloading", "importing"):
            return f"{self.stage.capitalize()} {self.done}/{self.total} tiles"
        if self.stage == "finishing":
            return "Joining and cropping"
        if self.stage == "failed":
            return str(self.error)
        return "Done"

    @property
    def fraction(self):
        if self.stage in ("downloading", "importing") and self.total:
            return self.done / self.total
        return 1.0 if self.stage in ("finishing", "done") else 0.0

    def start(self):
        _log(f"Selecting tiles within {self.radius:.0f} m of {self.lat:.6f}, {self.lon:.6f}")
        self._thread.start()

    def cancel(self):
        self._cancel.set()

    def abandon(self):
        """Stop without touching bpy data (it is about to be replaced by a file load)."""
        self._cancel.set()
        self._thread.join(timeout=65.0)
        self._remove_tmp()

    def _progress(self, done, total=0):
        self.done, self.total = done, total
        now = time.monotonic()
        if now - self._last_log >= 2.0 or (total and done == total):
            self._last_log = now
            _log(self.status)

    def _fetch(self):
        try:
            self._client = tiles.Client(self._key)
            refs = tiles.select_tiles(
                self._client,
                self.lat,
                self.lon,
                self.radius,
                self.max_error,
                max_tiles=self.max_tiles,
                progress=lambda n, _visit: self._progress(n),
                cancel=self._cancel.is_set,
            )
            if not refs:
                raise tiles.TilesError("No tiles intersect the requested area")
            self._tmp = tempfile.mkdtemp(prefix="earth-tiles-")
            self.done, self.total = 0, len(refs)
            self.stage = "downloading"
            paths, copyrights = tiles.download_tiles(
                self._client,
                refs,
                self.lat,
                self.lon,
                self._tmp,
                progress=self._progress,
                cancel=self._cancel.is_set,
            )
            self.credit = tiles.attribution(copyrights)
            self._paths = paths
            self.done = 0
            self.stage = "importing"
        except Exception as e:  # reported on the main thread by step()
            self.error = e

    def step(self, budget=0.1):
        """Advance on the main thread. Returns True once finished, failed, or cancelled."""
        if self.error is None and self._cancel.is_set():
            self.error = tiles.Cancelled()
        if self.error is not None:
            if self._thread.is_alive():
                return False  # let the worker stop before removing its temp dir
            self._abort()
            return True
        try:
            if self.stage == "importing":
                self._import_some(budget)
            elif self.stage == "finishing":
                self._finish()
                self.stage = "done"
                _log(f"Imported {len(self._meshes)} meshes from {self._client.requests} requests")
                _log(f"Attribution: {self.credit}")
                return True
        except Exception as e:
            self.error = e
            self._abort()
            return True
        return False

    def _import_some(self, budget):
        if self._coll is None:
            self._coll = bpy.data.collections.new(f"Earth {self.lat:.5f}, {self.lon:.5f}")
            bpy.context.scene.collection.children.link(self._coll)
        layer_coll = _find_layer_collection(bpy.context.view_layer.layer_collection, self._coll.name)
        bpy.context.view_layer.active_layer_collection = layer_coll
        deadline = time.monotonic() + budget
        first = self.done
        # At least one tile per step, then as many as fit in the budget.
        while self.done < len(self._paths) and (self.done == first or time.monotonic() < deadline):
            self._meshes.extend(_import_glb(self._paths[self.done]))
            self._progress(self.done + 1, self.total)
        if self.done == len(self._paths):
            # Embedded textures must not depend on the temp files about to be deleted.
            for mesh in self._meshes:
                for slot in mesh.material_slots:
                    if slot.material and slot.material.node_tree:
                        for node in slot.material.node_tree.nodes:
                            img = getattr(node, "image", None)
                            if img is not None and img.packed_file is None:
                                img.pack()
            self._remove_tmp()
            self.stage = "finishing"

    def _finish(self):
        if not self._meshes:
            raise tiles.TilesError("The selected tiles contained no meshes")
        if self.join:
            result = _join(self._meshes, f"Earth {self.lat:.5f}, {self.lon:.5f}")
            if self.crop:
                _crop(result, self.radius)
            if self.ground:
                _ground(result)
            result["google_attribution"] = self.credit
            result["source_location"] = f"{self.lat}, {self.lon}"
        else:
            result = self._meshes
        self._coll["google_attribution"] = self.credit
        if self.output:
            _export(result, self.output, self.credit, self.draco)
            _log(f"Wrote {self.output}")
        self.result = result

    def _abort(self):
        self.stage = "failed"
        for obj in self._meshes:
            if obj.name in bpy.data.objects:
                bpy.data.objects.remove(obj)
        if self._coll is not None and self._coll.name in bpy.data.collections:
            bpy.data.collections.remove(self._coll)
        self._meshes = []
        self._remove_tmp()
        _log(f"Failed: {self.error}")

    def _remove_tmp(self):
        if self._tmp:
            shutil.rmtree(self._tmp, ignore_errors=True)
            self._tmp = None


def generate(lat, lon, **kwargs):
    """Blocking import of the area around (lat, lon); see ImportJob for arguments.

    Returns (object or list of objects, attribution string).
    """
    job = ImportJob(lat, lon, **kwargs)
    job.start()
    while not job.step(budget=1.0):
        time.sleep(0.05)
    if job.error is not None:
        raise job.error
    return job.result, job.credit


def _log(msg):
    print(f"[earth_tiles] {msg}", flush=True)


def _import_glb(path):
    """Import one relocated tile; returns its mesh objects with transforms applied."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = []
    for obj in new:
        if obj.type == "MESH":
            obj.data.transform(obj.matrix_world)
            obj.parent = None
            obj.matrix_world = Matrix.Identity(4)
            meshes.append(obj)
    for obj in new:
        if obj.type != "MESH":
            bpy.data.objects.remove(obj)
    return meshes


def _find_layer_collection(layer_coll, name):
    if layer_coll.name == name:
        return layer_coll
    for child in layer_coll.children:
        found = _find_layer_collection(child, name)
        if found:
            return found
    return None


def _join(meshes, name):
    if len(meshes) > 1:
        with bpy.context.temp_override(
            active_object=meshes[0],
            object=meshes[0],
            selected_objects=meshes,
            selected_editable_objects=meshes,
        ):
            bpy.ops.object.join()
    obj = meshes[0]
    obj.name = name
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.01)
    bm.to_mesh(obj.data)
    bm.free()
    return obj


def _crop(obj, radius):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    r2 = radius * radius
    outside = [f for f in bm.faces if all(v.co.x ** 2 + v.co.y ** 2 > r2 for v in f.verts)]
    bmesh.ops.delete(bm, geom=outside, context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()


def _ground(obj):
    """Shift the model so its lowest point sits at z = 0."""
    if not obj.data.vertices:
        return
    zmin = min(v.co.z for v in obj.data.vertices)
    obj.data.transform(Matrix.Translation((0.0, 0.0, -zmin)))


def _export(objs, output, credit, draco):
    objs = objs if isinstance(objs, list) else [objs]
    with bpy.context.temp_override(selected_objects=objs, active_object=objs[0]):
        for o in bpy.context.view_layer.objects:
            o.select_set(o in objs)
        bpy.ops.export_scene.gltf(
            filepath=output,
            export_format="GLB",
            use_selection=True,
            export_apply=True,
            export_copyright=credit or "Google",
            export_draco_mesh_compression_enable=draco,
        )
