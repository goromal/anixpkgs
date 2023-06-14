{ callPackage
, pytestCheckHook
, buildPythonPackage
, click
}:
callPackage ../pythonPkgFromScript.nix {
    pname = "fqt";
    version = "1.0.0";
    description = "Four-quadrant tasking.";
    script-file = ./fqt.py;
    inherit pytestCheckHook buildPythonPackage;
    propagatedBuildInputs = [ click ];
    checkPkgs = [];
}
