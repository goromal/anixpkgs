{ stdenv
, cmake
, eigen
, manif-geom-cpp
, boost
}:
stdenv.mkDerivation {
    name = "signals-cpp";
    version = "1.0.0";
    src = builtins.fetchGit (import ./src.nix);
    nativeBuildInputs = [
        cmake
    ];
    buildInputs = [
        eigen
        boost
        manif-geom-cpp
    ];
    preConfigure = ''
    cmakeFlags="$cmakeFlags --no-warn-unused-cli"
    '';
}
