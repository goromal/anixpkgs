{ clangStdenv
, cmake
, eigen
, boost
, pkg-src
}:
clangStdenv.mkDerivation {
    name = "manif-geom-cpp";
    version = "1.0.0";
    src = pkg-src;
    nativeBuildInputs = [
        cmake
    ];
    buildInputs = [
        eigen
        boost
    ];
    preConfigure = ''
    cmakeFlags="$cmakeFlags --no-warn-unused-cli"
    '';
    meta = {
        description = "test";
        longDescription = ''
        Something something $SO(3)$ and $SE(3)$.
        '';
    }
}
