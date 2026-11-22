bl_info = {
    "name": "Earth Tiles",
    "author": "Andrew Torgesen",
    "version": (0, 1, 0),
    "blender": (4, 2, 0),
    "location": "View3D > Sidebar > Earth",
    "description": "Import Google Photorealistic 3D Tiles around a location and export GLB",
    "category": "Import-Export",
}

try:
    import bpy  # noqa: F401
except ImportError:  # imported outside Blender (unit tests, earth-glb --help)
    bpy = None

if bpy is not None:
    from .ui import register, unregister  # noqa: F401
