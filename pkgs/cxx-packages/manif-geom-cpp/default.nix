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
        description = "Templated, header-only implementations for SO(2), SE(2), SO(3), SE(3).";
        longDescription = ''
            [Repository](https://github.com/goromal/manif-geom-cpp)

            $$R(q)=I$$
        '';
    };
}
