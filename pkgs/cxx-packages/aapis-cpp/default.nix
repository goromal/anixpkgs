{ clangStdenv
, cmake
, protobuf
, pkg-src
}:
clangStdenv.mkDerivation {
    name = "aapis-cpp";
    version = "0.0.0";
    src = pkg-src;
    nativeBuildInputs = [
        cmake
        protobuf
    ];
    patchPhase = ''
        shopt -s globstar
        cp ${./CMakeLists.txt} CMakeLists.txt
        for proto in **/*.proto; do
            protoc -I protos --cpp_out=protos $proto
        done
        echo "set(sources" > ./src.cmake; find . -name "*.cc" >> ./src.cmake; echo ")" >> ./src.cmake;
        echo "set(headers" > ./include.cmake; find . -name "*.h" >> ./include.cmake; echo ")" >> ./include.cmake
    '';
}
