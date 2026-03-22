{
  callPackage,
  clangStdenv,
  cmake,
  ceres-solver,
  ceres-factors,
  manif-geom-cpp,
  eigen,
  numpy,
  geometry,
  pyceres,
  pybind11,
  python,
  pythonOlder,
  pytestCheckHook,
  buildPythonPackage,
  pkg-src,
}:
callPackage ../pythonPkgFromPybind.nix {
  pname = "PyCeresFactors";
  version = "1.0.0";
  description = "Python bindings of ceres-factors.";
  inherit clangStdenv;
  inherit pkg-src;
  cppNativeBuildInputs = [ cmake ];
  cppBuildInputs = [
    ceres-solver
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
  propagatedBuildInputs = [ ];
  checkPkgs = [
    numpy
    geometry
    pyceres
  ];
  longDescription = ''
    [Repository](https://github.com/goromal/pyceres_factors)

    **[Tutorial](https://notes.andrewtorgesen.com/doku.php?id=public:autonomy:implementation:opt-libs:ceres)** on how to use the library in conjunction with [pyceres](./pyceres.md) and [geometry](./geometry.md).
  '';
}
