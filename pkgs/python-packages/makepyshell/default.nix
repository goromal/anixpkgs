{ callPackage
, pytestCheckHook
, buildPythonPackage
}:
callPackage ../pythonPkgFromScript.nix {
    pname = "makepyshell";
    version = "1.0.0";
    description = "Generate a nix-shell file for Python development.";
    script-file = (builtins.fetchGit (import ./src.nix)) + "/makepyshell.py";
    inherit pytestCheckHook buildPythonPackage;
    propagatedBuildInputs = [];
    checkPkgs = [];
}
