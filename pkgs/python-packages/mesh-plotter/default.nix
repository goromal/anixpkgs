{ buildPythonPackage
, fetchPypi
, pythonOlder
, numpy
, matplotlib
, geometry
, pysignals
, pkg-src
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
    src = pkg-src;
}
