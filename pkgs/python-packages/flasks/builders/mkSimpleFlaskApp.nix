{ pname
, version
, buildPythonPackage
, flask
, writeTextFile
, flaskScript
, overrideFullFlaskScript ? false
, helperScript ? null
, templateText ? null
, writeShellScript
, scriptPropagatedBuildInputs
, python
}:
let
    use_template = templateText != null;
    use_helper = helperScript != null;
    pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
    template_file = if use_template then writeTextFile {
        name = "index.html";
        text = templateText;
    } else null;
    template_file_pytxt = if use_template then ''
        @app.route('/', methods=['GET', 'POST'])
        def index():
            return flask.render_template('index.html')
    '' else "";
    template_file_setup = if use_template then ''
        mkdir -p $out/${pythonLibDir}/templates
        cp ${template_file} $out/${pythonLibDir}/templates/index.html
    '' else "";
    helper_script = if use_helper then writeShellScript "helper_script.sh" ''
        ${helperScript}
    '' else null;
    helper_script_pytxt = if use_helper then ''
        import os
        helper_script = os.path.join(os.path.dirname(os.path.realpath(__file__)), 'helper_script.sh')
    '' else "";
    helper_script_setup = if use_helper then ''
        cp ${helper_script} $out/${pythonLibDir}/helper_script.sh
    '' else "";
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
        text = if ! overrideFullFlaskScript then ''
            import flask
            import argparse
            app = flask.Flask(__name__)
            ${helper_script_pytxt}
            ${template_file_pytxt}
            ${flaskScript}
            def run():
                parser = argparse.ArgumentParser()
                parser.add_argument("--port", action="store", type=int, default=5000, help="Port to run the server on")
                args = parser.parse_args()
                app.run(host="0.0.0.0", port=args.port)
            if __name__ == "__main__":
                run()
        '' else flaskScript;
    };
in buildPythonPackage rec {
    inherit pname;
    inherit version;
    src = ./.;
    prePatch = ''
        ${template_file_setup}
        ${helper_script_setup}
        cp ${setup_file} setup.py
        cp ${script_file} ${pname}.py
    '';
    propagatedBuildInputs = [ flask ] ++ scriptPropagatedBuildInputs;
}
