{ clangStdenv
, cmake
, eigen
, manif-geom-cpp
, boost
, pkg-src
}:
clangStdenv.mkDerivation {
    name = "signals-cpp";
    version = "1.0.0";
    src = pkg-src;
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
