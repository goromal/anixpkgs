{ buildPythonPackage
, flask
, writeTextFile
, callPackage
, writeShellScript
, python
}:
callPackage ../builders/mkSimpleFlaskApp.nix {
    pname = "flask_hello_world";
    version = "0.0.0";
    inherit buildPythonPackage flask writeTextFile writeShellScript python;
    scriptPropagatedBuildInputs = [];
    flaskScript = ''
        @app.route('/')
        def hello_world():
            return 'Hello, World! Oh, the places we will go!'
    '';
}
