{
  lib,
  stdenvNoCC,
  symlinkJoin,
  makeWrapper,
  writeShellScriptBin,
  blender,
  python3,
}:
let
  pkgname = "blender-earth";
  scripts = stdenvNoCC.mkDerivation {
    pname = "${pkgname}-scripts";
    version = "0.1.0";
    src = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.unions [
        ./earth_tiles
        ./earth_tiles_enable.py
        ./earth_glb.py
        ./test_tiles.py
        ./e2e_blender.py
      ];
    };
    nativeBuildInputs = [
      python3
      blender
    ];
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/scripts/addons $out/scripts/startup
      cp -r earth_tiles $out/scripts/addons/
      cp earth_tiles_enable.py $out/scripts/startup/
      cp earth_glb.py $out/
    '';
    doInstallCheck = true;
    installCheckPhase = ''
      export HOME=$TMPDIR
      python3 -m unittest -v test_tiles
      blender -b --factory-startup --python e2e_blender.py -- $out/scripts/addons
    '';
  };
  earth-glb = writeShellScriptBin "earth-glb" ''
    for arg in "$@"; do
      if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
        exec ${python3}/bin/python3 ${scripts}/earth_glb.py -- --help
      fi
    done
    exec ${blender}/bin/blender -b --factory-startup --python ${scripts}/earth_glb.py -- "$@"
  '';
in
symlinkJoin {
  name = pkgname;
  paths = [
    blender
    earth-glb
  ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    rm $out/bin/blender
    makeWrapper ${blender}/bin/blender $out/bin/blender \
      --set BLENDER_SYSTEM_SCRIPTS ${scripts}/scripts
  '';
  passthru = { inherit scripts; };
  meta = {
    description = "Blender with an add-on that imports Google Photorealistic 3D Tiles around a location and exports GLB.";
    longDescription = ''
      Provides a wrapped `blender` with the **Earth Tiles** add-on enabled
      (View3D > Sidebar > Earth) and a headless `earth-glb` CLI.

      Requires a Google Cloud project with billing enabled and the Map Tiles API
      turned on. The API key is read from `$GOOGLE_MAP_TILES_API_KEY`, then the
      add-on preference, then `~/secrets/google/maps.json` (`{"key": "..."}`
      or a bare key). Each generation makes one billable root tileset request
      (1,000 free per month).

      Google's Map Tiles API policies restrict caching tile content and deriving
      3D models from it; the tool deletes downloaded tiles after import and
      writes Google's attribution into the output GLB's `asset.copyright`.

      ```
      usage: earth-glb [-h] -o OUTPUT [-r RADIUS] [-e MAX_ERROR] [--max-tiles MAX_TILES]
                       [--key-file KEY_FILE] [--no-crop] [--no-ground] [--draco]
                       [--blend BLEND]
                       location

      $ earth-glb "40.748440, -73.985664" -r 150 -o empire-state.glb
      ```

      `--max-error` (meters) sets the level of detail: tiles are refined until
      their geometric error is at most this value.
    '';
  };
}
