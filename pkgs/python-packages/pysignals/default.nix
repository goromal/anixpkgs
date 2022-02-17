{ callPackage
, pytestCheckHook
, buildPythonPackage
, numpy
, geometry
}:
# TODO replace with pybind11 package
callPackage ../pythonPkgFromScript.nix {
    pname = "pysignals";
    version = "0.0.0";
    description = ".";
    is-exec = false;
    script-file = ./pysignals.py;
    test-dir = ./tests/.;
    inherit pytestCheckHook buildPythonPackage;
    checkPkgs = [
        numpy
        geometry
    ];
}
