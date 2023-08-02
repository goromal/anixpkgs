{ callPackage
, clangStdenv
, cmake
, ceres-solver
, eigen
, glog
, gflags
, suitesparse
, pybind11
, python
, pythonOlder
, pytestCheckHook
, buildPythonPackage
, pkg-src
}:
callPackage ../pythonPkgFromPybind.nix {
    pname = "PyCeres";
    version = "2.0.0";
    description = "Python bindings for the Ceres Solver.";
    inherit clangStdenv;
    inherit pkg-src;
    cppNativeBuildInputs = [
        cmake
    ];
    cppBuildInputs = [
        ceres-solver
        eigen
        glog
        gflags
        suitesparse
    ];
    cppSetup = ''
        sed -i 's|set(CMAKE_MODULE_PATH "''${CMAKE_CURRENT_SOURCE_DIR}/cmake")|set(CMAKE_CXX_FLAGS "''${CMAKE_CXX_FLAGS} -std=c++17")|g' CMakeLists.txt
        sed -i 's|add_subdirectory(pybind11)|find_package(pybind11 REQUIRED)|g' CMakeLists.txt
        sed -i 's|include_directories(''${CERES_INCLUDE_DIR})||g' CMakeLists.txt
        sed -i 's|''${CERES_LIBRARY}|Ceres::ceres|g' CMakeLists.txt
        sed -i 's|normal_prior.def(py::init<const ceres::Matrix \&, const ceres::Vector &>());|normal_prior.def(py::init<const ceres::Matrix \&, const ceres::Vector \&>());\n/*|g' python_bindings/python_module.cpp
        sed -i 's|py::class_<ceres::Covariance::Options> cov_opt(m, "CovarianceOptions");|\*\/\npy::class_<ceres::Covariance::Options> cov_opt(m, "CovarianceOptions");|g' python_bindings/python_module.cpp
    '';
    inherit pybind11;
    inherit python;
    inherit pythonOlder;
    inherit pytestCheckHook;
    inherit buildPythonPackage;
    propagatedBuildInputs = [];
    checkPkgs = [];
    longDescription = ''
    **[Tutorial](https://notes.andrewtorgesen.com/doku.php?id=public:ceres)** on how to use the library in conjunction with [pyceres_factors](./pyceres_factors.md) and [geometry](./geometry.md).
    '';
}
