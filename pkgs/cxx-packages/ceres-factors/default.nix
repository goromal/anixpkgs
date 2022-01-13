{ stdenv
, cmake
, eigen
, ceres
, manif-geom-cpp
, boost
}:
stdenv.mkDerivation {
    name = "ceres-factors";
    version = "1.0.0";
    src = builtins.fetchGit (import ./src.nix);
    nativeBuildInputs = [
        cmake
    ];
    buildInputs = [
        eigen
        ceres
        manif-geom-cpp
        boost
    ];
    preConfigure = ''
    cmakeFlags="$cmakeFlags --no-warn-unused-cli"
    '';
}
