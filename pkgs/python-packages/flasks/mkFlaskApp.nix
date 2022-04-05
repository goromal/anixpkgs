{ pname
, version
, buildPythonApplication
, flask
, writeTextFile
, flaskScript
, scriptPropagatedBuildInputs
}:
let
    setup_file = writeTextFile {
        name = "setup.py";
        text = ''
            from setuptools import setup
            setup(
                name='${pname}',
                version='${version}',
                py_modules=['${pname}'],
                entry_points={
                    'console_scripts': ['${pname} = ${pname}:run']
                },
            )
        '';
    };
    script_file = writeTextFile {
        name = "${pname}.py";
        text = ''
            import flask
            app = flask.Flask(__name__)
            ${flaskScript}
            def run():
                app.run(host="0.0.0.0")
            if __name__ == "__main__":
                run()
        '';
    };
in buildPythonApplication rec {
    inherit pname;
    inherit version;
    src = ./.;
    prePatch = ''
        cp ${setup_file} setup.py
        cp ${script_file} ${pname}.py
    '';
    propagatedBuildInputs = [ flask ] ++ scriptPropagatedBuildInputs;
}