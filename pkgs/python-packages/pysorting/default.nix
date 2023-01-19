{ callPackage
, clangStdenv
, cmake
, sorting
, pybind11
, python
, pythonOlder
, pytestCheckHook
, buildPythonPackage
, pkg-src
}:
callPackage ../pythonPkgFromPybind.nix {
    pname = "pysorting";
    version = "1.0.0";
    description = "RESTful incremental sorting with client-side comparators.";
    inherit clangStdenv;
    inherit pkg-src;
    cppNativeBuildInputs = [
        cmake
    ];
    cppBuildInputs = [
        sorting
    ];
    hasTests = true;
    inherit pybind11;
    inherit python;
    inherit pythonOlder;
    inherit pytestCheckHook;
    inherit buildPythonPackage;
    propagatedBuildInputs = [];
    checkPkgs = [];
}
