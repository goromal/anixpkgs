{ callPackage
, stdenv
, cmake
, manif-geom-cpp 
, eigen
, pybind11
, python
, buildPythonPackage
}:
callPackage ../pythonPkgFromPybind {
    pname = "geometry";
    version = "1.0.0";
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