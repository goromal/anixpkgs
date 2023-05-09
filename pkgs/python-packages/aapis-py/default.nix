{ buildPythonPackage
, buildPython
, protobuf
, apis-fds
, pkg-src
, grpc-support ? true
}:
let
    bldCmd = if grpc-support then (
        let 
            py = buildPython.withPackages(
                p: with p; [ mypy-protobuf grpcio-tools ]
            );
        in ''
        ${py}/bin/python3 -m grpc_tools.protoc                    \
            --proto_path=protos                                   \
            --plugin=${py.pkgs.mypy-protobuf}/bin/protoc-gen-mypy \
            --python_out=aapis_py                                 \
            --grpc_python_out=aapis_py                            \
            --mypy_out=aapis_py                                   \
            protos/**/*.proto
    ''
    ) else ''
        for proto in **/*.proto; do
            protoc -I protos --python_out=aapis_py $proto
        done
    '';
in buildPythonPackage rec {
    pname = "aapis-py";
    version = "0.0.0";
    src = pkg-src;
    propagatedBuildInputs = [
        protobuf
    ];
    patchPhase = ''
        shopt -s globstar
        cp ${./setup.py} setup.py
        mkdir -p aapis_py/aapis_fds
        touch aapis_py/aapis_fds/__init__.py
        touch aapis_py/aapis_fds/py.typed
        cp ${apis-fds} aapis_py/aapis_fds/aapis.desc
        touch aapis_py/aapis/py.typed
        ${bldCmd}
    '';
}
