{ callPackage
, clangStdenv
, cmake
, signals-cpp
, manif-geom-cpp
, eigen
, pybind11
, python
, pythonOlder
, pytestCheckHook
, buildPythonPackage
, numpy
, geometry
}:
callPackage ../pythonPkgFromPybind.nix {
    pname = "pysignals";
    version = "1.0.0";
    description = "Python bindings of signals-cpp.";
    inherit clangStdenv;
    pkg-src = builtins.fetchGit (import ./src.nix);
    cppNativeBuildInputs = [
        cmake
    ];
    cppBuildInputs = [
        signals-cpp
        manif-geom-cpp
        eigen
    ];
    hasTests = true;
    inherit pybind11;
    inherit python;
    inherit pythonOlder;
    inherit pytestCheckHook;
    inherit buildPythonPackage;
    propagatedBuildInputs = [];
    checkPkgs = [
        numpy
        geometry
    ];
}
