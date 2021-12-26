{ stdenv
, cmake
, eigen
, boost
}:
stdenv.mkDerivation {
    name = "manif-geom-cpp";
    version = "1.0.0";
    src = builtins.fetchGit (import ./src.nix);
    nativeBuildInputs = [
        cmake
    ];
    buildInputs = [
        eigen
        boost
    ];
}