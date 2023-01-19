{ callPackage
, pytestCheckHook
, buildPythonPackage
}:
callPackage ../pythonPkgFromScript.nix {
    pname = "sunnyside";
    version = "1.0.0";
    description = "Make scrambled eggs.";
    script-file = ./sunnyside.py;
    inherit pytestCheckHook buildPythonPackage;
    propagatedBuildInputs = [];
    checkPkgs = [];
}
