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
    src = builtins.fetchGit {
        url = "git@github.com:goromal/mesh-plotter.git";
        rev = "aee00d7b5f6ba56e3870a0bef33f76569a144536";
        ref = "master";
    };
}