{ callPackage
, stdenv
, cmake
, manif-geom-cpp
, eigen
, glog
, gflags
, suitesparse
, pybind11
, python
, pythonOlder
, buildPythonPackage
}:
callPackage ../pythonPkgFromPybind.nix {
    pname = "pyceres";
    version = "2.0.0";
    description = "Python bindings for the Ceres Solver.";
    inherit stdenv;
    pkg-src = builtins.fetchGit (import ./src.nix);
    cppNativeBuildInputs = [
        cmake
    ];
    cppBuildInputs = [
        manif-geom-cpp
        eigen
        glog
        gflags
        suitesparse
    ];
    cppTarget = "lib/pyceres*";
    inherit pybind11;
    inherit python;
    inherit pythonOlder;
    inherit buildPythonPackage;
    propagatedBuildInputs = [];
}
