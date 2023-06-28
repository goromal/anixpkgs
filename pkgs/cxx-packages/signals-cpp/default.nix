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
    meta = {
        description = "Header-only templated C++ library implementing rigid-body dynamics, derivatives, integrals, and interpolation.";
        longDescription = ''
        [Repository](https://github.com/goromal/signals-cpp)

        Examples documented in the [unit tests](https://github.com/goromal/signals-cpp/tree/master/tests).
        '';
    };
}
