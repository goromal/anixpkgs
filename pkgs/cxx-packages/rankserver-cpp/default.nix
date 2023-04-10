{ clangStdenv
, cmake
, boost
, crowcpp
, sorting
}:
clangStdenv.mkDerivation {
    name = "rankserver-cpp";
    version = "1.0.0";
    src = pkg-src;
    nativeBuildInputs = [
        cmake
    ];
    buildInputs = [
        boost
        crowcpp
        sorting
    ];
    preConfigure = ''
    cmakeFlags="$cmakeFlags --no-warn-unused-cli"
    '';
}
