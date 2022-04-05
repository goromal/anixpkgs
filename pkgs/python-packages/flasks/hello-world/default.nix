{ buildPythonApplication
, flask
, writeTextFile
, callPackage
}:
callPackage ../builders/mkSimpleFlaskApp.nix {
    pname = "flask_hello_world";
    version = "0.0.0";
    inherit buildPythonApplication flask writeTextFile;
    scriptPropagatedBuildInputs = [];
    flaskScript = ''
        @app.route('/')
        def hello_world():
            return 'Hello, World! Oh, the places we will go!'
    '';
}