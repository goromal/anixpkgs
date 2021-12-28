# No nix files in accel repo! Depend entirely on installed python packages
# perform all CI (for all other repos too!) from THIS repo
{ stdenv
, runCommand
, buildPythonPackage
, numpy
, requests
, colorama
, ffmpeg-python
, scipy
, networkx
, osqp
, geometry
, pyceres
}:
let
    pkg-src = builtins.fetchGit (import ./src.nix);
    getVersion = root: builtins.fromJSON (builtins.readFile (
        runCommand “get_accel_version” { buildInputs = [ python ]; } ‘’
        python ${root}/scripts/make_manifest.py > $out
        ‘’));
    versionInfo = getVersion pkg-src;
in buildPythonPackage rec {
    pname = versionInfo.pname;
    version = versionInfo.version;
    src = pkg-src;
    propagatedBuildInputs = [
        numpy
        requests
        colorama
	    ffmpeg-python
	    scipy
	    networkx
	    osqp
	    geometry
	    pyceres
    ];
    doCheck = false;
}
