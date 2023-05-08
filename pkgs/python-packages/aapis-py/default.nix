{ buildPythonPackage
, protobuf
, apis-fds
, pkg-src
}:
buildPythonPackage rec {
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
        for proto in **/*.proto; do
            protoc -I protos --python_out=aapis_py $proto
        done
        touch aapis_py/aapis/py.typed
    '';
}
