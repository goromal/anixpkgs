{ clangStdenv
, cmake
, eigen
, ceres-solver
, manif-geom-cpp
, boost
, pkg-src
}:
clangStdenv.mkDerivation {
    name = "ceres-factors";
    version = "1.0.0";
    src = pkg-src;
    nativeBuildInputs = [
        cmake
    ];
    buildInputs = [
        eigen
        ceres-solver
        manif-geom-cpp
        boost
    ];
    preConfigure = ''
    cmakeFlags="$cmakeFlags --no-warn-unused-cli"
    '';
}
