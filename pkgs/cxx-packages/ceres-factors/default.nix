{ clangStdenv
, cmake
, eigen
, ceres-solver
, manif-geom-cpp
, boost
}:
clangStdenv.mkDerivation {
    name = "ceres-factors";
    version = "1.0.0";
    src = builtins.fetchGit (import ./src.nix);
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
