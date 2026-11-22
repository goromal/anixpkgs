"""Blender-side import, cleanup, and GLB export of selected tiles."""

import shutil
import tempfile

import bmesh
import bpy
from mathutils import Matrix

from . import tiles


def generate(
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
    progress=print,
):
    """Import the area around (lat, lon) into a new collection.

    Returns (object or list of objects, attribution string). Writes a GLB to
    `output` when given.
    """
    client = tiles.Client(tiles.resolve_key(key, key_file))
    progress(f"Selecting tiles within {radius:.0f} m of {lat:.6f}, {lon:.6f}")
    refs = tiles.select_tiles(client, lat, lon, radius, max_error, max_tiles=max_tiles, progress=progress)
    if not refs:
        raise tiles.TilesError("No tiles intersect the requested area")

    tmp = tempfile.mkdtemp(prefix="earth-tiles-")
    try:
        paths, copyrights = tiles.download_tiles(client, refs, lat, lon, tmp, progress=progress)
        credit = tiles.attribution(copyrights)
        coll = bpy.data.collections.new(f"Earth {lat:.5f}, {lon:.5f}")
        bpy.context.scene.collection.children.link(coll)
        meshes = _import_glbs(paths, coll, progress)
        # Embedded textures must not depend on the temp files about to be deleted.
        for mesh in meshes:
            for slot in mesh.material_slots:
                if slot.material and slot.material.node_tree:
                    for node in slot.material.node_tree.nodes:
                        img = getattr(node, "image", None)
                        if img is not None and img.packed_file is None:
                            img.pack()
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    progress(f"Imported {len(meshes)} meshes from {client.requests} requests")

    if join:
        result = _join(meshes, f"Earth {lat:.5f}, {lon:.5f}")
        if crop:
            _crop(result, radius)
        if ground:
            _ground(result)
        result["google_attribution"] = credit
        result["source_location"] = f"{lat}, {lon}"
    else:
        result = meshes
    coll["google_attribution"] = credit

    if output:
        _export(result if join else meshes, output, credit, draco)
        progress(f"Wrote {output}")
    progress(f"Attribution: {credit}")
    return result, credit


def _import_glbs(paths, coll, progress):
    layer_coll = _find_layer_collection(bpy.context.view_layer.layer_collection, coll.name)
    bpy.context.view_layer.active_layer_collection = layer_coll
    meshes = []
    for n, path in enumerate(paths, 1):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=path)
        new = [o for o in bpy.data.objects if o not in before]
        for obj in new:
            if obj.type == "MESH":
                obj.data.transform(obj.matrix_world)
                obj.parent = None
                obj.matrix_world = Matrix.Identity(4)
                meshes.append(obj)
        for obj in new:
            if obj.type != "MESH":
                bpy.data.objects.remove(obj)
        if n % 25 == 0 or n == len(paths):
            progress(f"Imported {n}/{len(paths)} tiles")
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
