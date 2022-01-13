{ callPackage
, stdenv
, cmake
, ceres
, ceres-factors
, manif-geom-cpp 
, eigen
, pybind11
, python
, pythonOlder
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
    inherit pybind11;
    inherit python;
    inherit pythonOlder;
    inherit buildPythonPackage;
    propagatedBuildInputs = [];
}
