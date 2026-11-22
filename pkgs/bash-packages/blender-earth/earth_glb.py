# Headless entry point: blender -b --factory-startup --python earth_glb.py -- [args]
import argparse
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "scripts", "addons"))

from earth_tiles import tiles  # noqa: E402


def main(argv):
    parser = argparse.ArgumentParser(
        prog="earth-glb",
        description="Generate a GLB of the area around a location from Google Photorealistic 3D Tiles.",
    )
    parser.add_argument("location", help="'lat, lon' in degrees, e.g. '40.748440, -73.985664'")
    parser.add_argument("-o", "--output", required=True, help="output .glb path")
    parser.add_argument("-r", "--radius", type=float, default=200.0, help="radius in meters (default 200)")
    parser.add_argument(
        "-e", "--max-error", type=float, default=4.0, help="max tile geometric error in meters; smaller = more detail (default 4)"
    )
    parser.add_argument("--max-tiles", type=int, default=2000, help="abort if more tiles are selected (default 2000)")
    parser.add_argument("--key-file", default=tiles.DEFAULT_KEY_FILE, help=f"API key file (default {tiles.DEFAULT_KEY_FILE}; ${tiles.KEY_ENV} wins)")
    parser.add_argument("--no-crop", action="store_true", help="keep whole tiles instead of cropping to the radius")
    parser.add_argument("--no-ground", action="store_true", help="keep ENU heights instead of moving the lowest point to z=0")
    parser.add_argument("--draco", action="store_true", help="Draco-compress the output (crashes with the nixpkgs Blender 5.1 encoder)")
    parser.add_argument("--blend", help="also save the scene as a .blend file")
    args = parser.parse_args(argv)

    try:
        lat, lon = tiles.parse_location(args.location)
    except ValueError as e:
        parser.error(str(e))

    import bpy
    from earth_tiles import scene

    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)
    try:
        scene.generate(
            lat,
            lon,
            radius=args.radius,
            max_error=args.max_error,
            key_file=args.key_file,
            output=os.path.abspath(args.output),
            crop=not args.no_crop,
            ground=not args.no_ground,
            draco=args.draco,
            max_tiles=args.max_tiles,
        )
    except tiles.TilesError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    if args.blend:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(args.blend))
    return 0


argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
sys.exit(main(argv))
