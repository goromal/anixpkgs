{ clangStdenv
, cmake
, boost
, pkg-src
}:
clangStdenv.mkDerivation {
    name = "mscpp";
    version = "1.0.0";
    src = pkg-src;
    nativeBuildInputs = [
        cmake
    ];
    buildInputs = [
        boost
    ];
    preConfigure = ''
    cmakeFlags="$cmakeFlags --no-warn-unused-cli"
    '';
    meta = {
        description = "Useful template classes for creating multithreaded, interdependent microservices in C++.";
        longDescription = ''
        [Repository](https://github.com/goromal/mscpp)

        **Use cases pending.**
        '';
    };
}
