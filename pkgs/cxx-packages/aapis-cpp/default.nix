{ clangStdenv
, cmake
, protobuf
, which
, grpc
, pkg-src
, grpc-support ? true
}:
let
    suppBldCmd = if grpc-support then ''
        protoc -I protos                                      \
            --grpc_out=generate_mock_code=true:protos         \
            --plugin=protoc-gen-grpc=$(which grpc_cpp_plugin) \
            $proto
    '' else "";
in clangStdenv.mkDerivation {
    name = "aapis-cpp";
    version = "0.0.0";
    src = pkg-src;
    nativeBuildInputs = [
        cmake
        protobuf
    ] ++ (if grpc-support then [ which grpc ] else []);
    patchPhase = ''
        shopt -s globstar
        cp ${./CMakeLists.txt} CMakeLists.txt
        for proto in **/*.proto; do
            protoc -I protos --cpp_out=protos $proto
            ${suppBldCmd}
        done
        echo "set(sources" > ./src.cmake; find . -name "*.cc" >> ./src.cmake; echo ")" >> ./src.cmake;
        echo "set(headers" > ./include.cmake; find . -name "*.h" >> ./include.cmake; echo ")" >> ./include.cmake
    '';
    meta = {
        description = "C++ bindings for [my custom APIs](https://github.com/goromal/aapis).";
        longDescription = "";
    };
}
