"""Sidebar panel, preferences, and import operator."""

import bpy

from . import tiles


class EarthTilesPreferences(bpy.types.AddonPreferences):
    bl_idname = __package__

    api_key: bpy.props.StringProperty(
        name="API key",
        description=f"Google Map Tiles API key (overridden by ${tiles.KEY_ENV})",
        subtype="PASSWORD",
    )
    key_file: bpy.props.StringProperty(
        name="Key file",
        description="File holding the API key, used when the key field is empty",
        default=tiles.DEFAULT_KEY_FILE,
        subtype="FILE_PATH",
    )

    def draw(self, context):
        self.layout.prop(self, "api_key")
        self.layout.prop(self, "key_file")


class EarthTilesSettings(bpy.types.PropertyGroup):
    location: bpy.props.StringProperty(
        name="Location",
        description="'lat, lon' in degrees, e.g. pasted from Google Maps",
        default="40.748440, -73.985664",
    )
    radius: bpy.props.FloatProperty(name="Radius", default=200.0, min=10.0, max=5000.0, unit="LENGTH")
    max_error: bpy.props.FloatProperty(
        name="Max error",
        description="Stop refining once a tile's geometric error is at most this (smaller = more detail)",
        default=4.0,
        min=0.1,
        unit="LENGTH",
    )
    max_tiles: bpy.props.IntProperty(name="Max tiles", default=2000, min=1)
    crop: bpy.props.BoolProperty(name="Crop to radius", default=True)
    join: bpy.props.BoolProperty(name="Join tiles", default=True)
    ground: bpy.props.BoolProperty(name="Lowest point at z=0", default=True)
    output: bpy.props.StringProperty(name="GLB", subtype="FILE_PATH", default="//earth.glb")
    draco: bpy.props.BoolProperty(
        name="Draco compression",
        description="Compress the output mesh (the encoder in some Blender builds crashes)",
        default=False,
    )


class EARTH_OT_import(bpy.types.Operator):
    bl_idname = "earth_tiles.import_area"
    bl_label = "Import Area"
    bl_description = "Download the tiles around the location into a new collection"
    bl_options = {"REGISTER", "UNDO"}

    export: bpy.props.BoolProperty(default=False, options={"HIDDEN"})

    def execute(self, context):
        s = context.scene.earth_tiles
        prefs = context.preferences.addons[__package__].preferences
        try:
            lat, lon = tiles.parse_location(s.location)
        except ValueError as e:
            self.report({"ERROR"}, str(e))
            return {"CANCELLED"}
        output = bpy.path.abspath(s.output) if self.export else ""
        if self.export and not output:
            self.report({"ERROR"}, "Set a GLB output path")
            return {"CANCELLED"}
        from . import scene

        def progress(msg):
            print(f"[earth_tiles] {msg}")
            context.workspace.status_text_set(msg)

        try:
            _, credit = scene.generate(
                lat,
                lon,
                radius=s.radius,
                max_error=s.max_error,
                key=prefs.api_key,
                key_file=prefs.key_file,
                output=output,
                crop=s.crop,
                join=s.join,
                ground=s.ground,
                draco=s.draco,
                max_tiles=s.max_tiles,
                progress=progress,
            )
        except tiles.TilesError as e:
            self.report({"ERROR"}, str(e))
            return {"CANCELLED"}
        finally:
            context.workspace.status_text_set(None)
        self.report({"INFO"}, credit)
        return {"FINISHED"}


class EARTH_PT_panel(bpy.types.Panel):
    bl_label = "Earth Tiles"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "Earth"

    def draw(self, context):
        s = context.scene.earth_tiles
        col = self.layout.column()
        col.prop(s, "location")
        col.prop(s, "radius")
        col.prop(s, "max_error")
        col.prop(s, "max_tiles")
        col.prop(s, "crop")
        col.prop(s, "join")
        col.prop(s, "ground")
        col.operator(EARTH_OT_import.bl_idname, icon="WORLD").export = False
        col.separator()
        col.prop(s, "output")
        col.prop(s, "draco")
        col.operator(EARTH_OT_import.bl_idname, text="Import && Export GLB", icon="EXPORT").export = True
        col.separator()
        col.label(text="Imagery & 3D: Google", icon="INFO")


_classes = (EarthTilesPreferences, EarthTilesSettings, EARTH_OT_import, EARTH_PT_panel)


def register():
    for cls in _classes:
        bpy.utils.register_class(cls)
    bpy.types.Scene.earth_tiles = bpy.props.PointerProperty(type=EarthTilesSettings)


def unregister():
    del bpy.types.Scene.earth_tiles
    for cls in reversed(_classes):
        bpy.utils.unregister_class(cls)
