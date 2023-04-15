{ clangStdenv
, cmake
, asio
, boost
, crowcpp
, sorting
, pkg-src
}:
clangStdenv.mkDerivation {
    name = "rankserver-cpp";
    version = "1.0.0";
    src = pkg-src;
    nativeBuildInputs = [
        cmake
    ];
    buildInputs = [
        asio
        boost
        crowcpp
        sorting
    ];
    preConfigure = ''
    cmakeFlags="$cmakeFlags --no-warn-unused-cli"
    '';
}
