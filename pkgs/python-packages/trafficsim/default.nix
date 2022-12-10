{ callPackage
, pytestCheckHook
, buildPythonPackage
, numpy
, matplotlib
, geometry
, pysignals
}:
callPackage ../pythonPkgFromScript.nix {
    pname = "trafficsim";
    version = "1.0.0";
    description = "Simulate traffic.";
    script-file = (builtins.fetchGit (import ./src.nix)) + "/traffic.py";
    inherit pytestCheckHook buildPythonPackage;
    propagatedBuildInputs = [
        numpy
        matplotlib
        geometry
        pysignals
    ];
    checkPkgs = [];
}
