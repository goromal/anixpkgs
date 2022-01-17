{ callPackage
, stdenv
, cmake
, ceres
, ceres-factors
, manif-geom-cpp 
, eigen
, numpy
, geometry
, pyceres
, pybind11
, python
, pythonOlder
, pytestCheckHook
, buildPythonPackage
}:
callPackage ../pythonPkgFromPybind.nix {
    pname = "PyCeresFactors";
    version = "1.0.0";
    description = "Python bindings of ceres-factors.";
    inherit stdenv;
    pkg-src = builtins.fetchGit (import ./src.nix);
    cppNativeBuildInputs = [
        cmake
    ];
    cppBuildInputs = [
        ceres
        ceres-factors
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
        pyceres
    ];
}
