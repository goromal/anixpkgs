{ callPackage
, stdenv
, cmake
, manif-geom-cpp 
, eigen
, pybind11
, python
, buildPythonPackage
}:
callPackage ../pythonPkgFromPybind.nix {
    pname = "geometry";
    version = "1.0.0";
    description = "Implementations for SO(3) and SE(3).";
    inherit stdenv;
    pkg-src = builtins.fetchGit (import ./src.nix);
    cppNativeBuildInputs = [
        cmake
    ];
    cppBuildInputs = [
        manif-geom-cpp
        eigen
    ];
    inherit pybind11;
    inherit python;
    inherit buildPythonPackage;
    propagatedBuildInputs = [];
}