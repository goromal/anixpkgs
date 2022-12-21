{ callPackage
, pytestCheckHook
, buildPythonPackage
, pkg-src
}:
callPackage ../pythonPkgFromScript.nix {
    pname = "makepyshell";
    version = "1.0.0";
    description = "Generate a nix-shell file for Python development.";
    script-file = "${pkg-src}/makepyshell.py";
    inherit pytestCheckHook buildPythonPackage;
    propagatedBuildInputs = [];
    checkPkgs = [];
}
