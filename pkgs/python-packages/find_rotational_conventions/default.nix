{ callPackage
, pytestCheckHook
, buildPythonPackage
, numpy
, geometry
, pkg-src
}:
callPackage ../pythonPkgFromScript.nix {
    pname = "find_rotational_conventions";
    version = "1.0.0";
    description = "Find rotational conventions of a Python transform library.";
    script-file = "${pkg-src}/find_rotational_conventions.py";
    inherit pytestCheckHook buildPythonPackage;
    propagatedBuildInputs = [
        numpy
        geometry
    ];
    checkPkgs = [];
}
