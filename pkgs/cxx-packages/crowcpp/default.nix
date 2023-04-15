{ clangStdenv
, cmake
, asio
, zlib
, openssl
, pkg-src
}:
clangStdenv.mkDerivation {
    name = "crowcpp";
    version = "1.0.0";
    src = pkg-src;
    nativeBuildInputs = [
        cmake
    ];
    buildInputs = [
        asio
        zlib
        openssl
    ];
    preConfigure = ''
    cmakeFlags="$cmakeFlags --no-warn-unused-cli"
    '';
}
