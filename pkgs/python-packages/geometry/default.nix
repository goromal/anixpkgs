{ callPackage
, clangStdenv
, cmake
, manif-geom-cpp 
, eigen
, numpy
, pybind11
, python
, pythonOlder
, pytestCheckHook
, buildPythonPackage
, pkg-src
}:
callPackage ../pythonPkgFromPybind.nix {
    pname = "geometry";
    version = "1.0.0";
    description = "Implementations for SO(3) and SE(3).";
    inherit clangStdenv;
    inherit pkg-src;
    cppNativeBuildInputs = [
        cmake
    ];
    cppBuildInputs = [
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
    checkPkgs = [ numpy ];
}