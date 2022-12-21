{ callPackage
, pytestCheckHook
, buildPythonPackage
, numpy
, matplotlib
, geometry
, pysignals
, pkg-src
}:
callPackage ../pythonPkgFromScript.nix {
    pname = "trafficsim";
    version = "1.0.0";
    description = "Simulate traffic.";
    script-file = "${pkg-src}/traffic.py";
    inherit pytestCheckHook buildPythonPackage;
    propagatedBuildInputs = [
        numpy
        matplotlib
        geometry
        pysignals
    ];
    checkPkgs = [];
}
