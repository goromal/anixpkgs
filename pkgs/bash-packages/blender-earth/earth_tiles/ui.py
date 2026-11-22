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


# The running import, if any. Only one at a time; the panel draws its progress.
_job = None


def _redraw(context):
    for window in context.window_manager.windows:
        for area in window.screen.areas:
            if area.type == "VIEW_3D":
                area.tag_redraw()


class EARTH_OT_import(bpy.types.Operator):
    bl_idname = "earth_tiles.import_area"
    bl_label = "Import Area"
    bl_description = "Download the tiles around the location into a new collection"
    bl_options = {"REGISTER", "UNDO"}

    export: bpy.props.BoolProperty(default=False, options={"HIDDEN"})

    @classmethod
    def poll(cls, context):
        return _job is None

    def execute(self, context):
        global _job
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

        try:
            _job = scene.ImportJob(
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
            )
        except tiles.TilesError as e:
            self.report({"ERROR"}, str(e))
            return {"CANCELLED"}
        _job.start()
        wm = context.window_manager
        self._timer = wm.event_timer_add(0.1, window=context.window)
        wm.modal_handler_add(self)
        return {"RUNNING_MODAL"}

    def modal(self, context, event):
        global _job
        if _job is None:  # cancelled by a file load
            return self._end(context, {"CANCELLED"})
        if event.type == "ESC" and event.value == "PRESS":
            _job.cancel()
            return {"RUNNING_MODAL"}
        if event.type != "TIMER":
            return {"PASS_THROUGH"}
        finished = _job.step()
        context.workspace.status_text_set(f"Earth Tiles: {_job.status} (Esc to cancel)")
        _redraw(context)
        if not finished:
            return {"PASS_THROUGH"}
        job, _job = _job, None
        if job.error is not None:
            level = {"WARNING"} if isinstance(job.error, tiles.Cancelled) else {"ERROR"}
            self.report(level, str(job.error))
            return self._end(context, {"CANCELLED"})
        self.report({"INFO"}, job.credit)
        return self._end(context, {"FINISHED"})

    def _end(self, context, result):
        context.window_manager.event_timer_remove(self._timer)
        context.workspace.status_text_set(None)
        _redraw(context)
        return result


class EARTH_OT_cancel(bpy.types.Operator):
    bl_idname = "earth_tiles.cancel"
    bl_label = "Cancel"
    bl_description = "Stop the running import and remove what it added"

    @classmethod
    def poll(cls, context):
        return _job is not None

    def execute(self, context):
        _job.cancel()
        return {"FINISHED"}


@bpy.app.handlers.persistent
def _cancel_on_load(*_args):
    global _job
    if _job is not None:
        _job.abandon()
        _job = None


class EARTH_PT_panel(bpy.types.Panel):
    bl_label = "Earth Tiles"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "Earth"

    def draw(self, context):
        s = context.scene.earth_tiles
        col = self.layout.column()
        col.enabled = _job is None
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
        if _job is not None:
            box = self.layout.box()
            box.progress(factor=_job.fraction, type="BAR", text=_job.status)
            box.operator(EARTH_OT_cancel.bl_idname, icon="CANCEL")
        self.layout.label(text="Imagery & 3D: Google", icon="INFO")


_classes = (EarthTilesPreferences, EarthTilesSettings, EARTH_OT_import, EARTH_OT_cancel, EARTH_PT_panel)


def register():
    for cls in _classes:
        bpy.utils.register_class(cls)
    bpy.types.Scene.earth_tiles = bpy.props.PointerProperty(type=EarthTilesSettings)
    bpy.app.handlers.load_pre.append(_cancel_on_load)


def unregister():
    _cancel_on_load()
    if _cancel_on_load in bpy.app.handlers.load_pre:
        bpy.app.handlers.load_pre.remove(_cancel_on_load)
    del bpy.types.Scene.earth_tiles
    for cls in reversed(_classes):
        bpy.utils.unregister_class(cls)
