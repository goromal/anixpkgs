{ buildPythonPackage
, fetchPypi
, pythonOlder
, numpy
, matplotlib
, geometry
, pysignals
}:
buildPythonPackage rec {
    pname = "mesh_plotter";
    version = "0.0.1";
    disabled = pythonOlder "3.6";
    doCheck = false;
    propagatedBuildInputs = [
        numpy
        matplotlib
        geometry
        pysignals
    ];
    src = builtins.fetchGit (import ./src.nix);
}
