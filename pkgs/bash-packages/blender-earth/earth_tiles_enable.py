# Startup hook: Blender only puts system add-on dirs on sys.path after startup
# scripts run, so add ours first and enable earth_tiles.
import os
import sys

import addon_utils


def register():
    addons = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "addons")
    if addons not in sys.path:
        sys.path.append(addons)
    addon_utils.enable("earth_tiles", default_set=True)


def unregister():
    pass
