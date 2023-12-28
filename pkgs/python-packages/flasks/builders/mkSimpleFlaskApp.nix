{ pname, version, buildPythonPackage, flask, writeTextFile, flaskScript
, overrideFullFlaskScript ? false, helperScript ? null, templateText ? null
, writeShellScript, scriptPropagatedBuildInputs, python, description
, longDescription ? "" }:
let
  use_template = templateText != null;
  use_helper = helperScript != null;
  pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
  template_file = if use_template then
    writeTextFile {
      name = "index.html";
      text = templateText;
    }
  else
    null;
  template_file_pytxt = if use_template then ''
    @app.route('/', methods=['GET', 'POST'])
    def index():
        return flask.render_template('index.html')
  '' else
    "";
  template_file_setup = if use_template then ''
    mkdir -p $out/${pythonLibDir}/templates
    cp ${template_file} $out/${pythonLibDir}/templates/index.html
  '' else
    "";
  helper_script = if use_helper then
    writeShellScript "helper_script.sh" ''
      ${helperScript}
    ''
  else
    null;
  helper_script_pytxt = if use_helper then ''
    import os
    helper_script = os.path.join(os.path.dirname(os.path.realpath(__file__)), 'helper_script.sh')
  '' else
    "";
  helper_script_setup = if use_helper then ''
    cp ${helper_script} $out/${pythonLibDir}/helper_script.sh
  '' else
    "";
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
    text = if !overrideFullFlaskScript then ''
      import flask
      import flask_login
      import flask_wtf
      from wtforms import StringField, PasswordField, SubmitField
      from werkzeug.security import generate_password_hash
      import argparse

      class LoginForm(flask_wtf.FlaskForm):
          username = StringField("Username")
          password = PasswordField("Password")
          submit = SubmitField("Submit")

      class User:
          def __init__(self):
              self.is_authenticated = False
              self.is_active = True
              self.is_anonymous = True
          def check_password(self, password):
              return generate_password_hash(password) == "pbkdf2:sha256:260000$EuvRGQYWUOui9Y83$f70a1c1f22d4d590111f05e2ca462ef4eaac382bff39323bc5b6da6172b13957"
          def get_id(self):
              return "anonymous"

      app = flask.Flask(__name__)
      app.secret_key = b"71d2dcdb895b367a1d5f0c66ca559c8d69af0c29a7e101c18c7c2d10399f264e"
      login_manager = flask_login.LoginManager()

      @login_manager.user_loader
      def load_user(user_id):
          if user_id == "anonymous":
              return User()
          else:
              return None
      
      @app.route("/login", methods=["GET", "POST"])
      def login():
          if current_user.is_authenticated:
              return redirect(url_for('index'))
          form = LoginForm()
          if form.validate_on_submit():
              user = User()
              if form.username.data != user.get_id() or not user.check_password(form.password.data):
                  flask.flash("Invalid username or password")
                  return redirect(flask.url_for("login"))
              flask_login.login_user(user, remember=False)
              return flask.redirect(flask.url_for("index"))
          return render_template("login.html", title="Sign In", form=form)
      
      @app.route("/logout")
      def logout():
          flask_login.logout_user()
          return flask.redirect(flask.url_for("index"))

      ${helper_script_pytxt}
      ${template_file_pytxt}
      ${flaskScript}

      def run():
          parser = argparse.ArgumentParser()
          parser.add_argument("--port", action="store", type=int, default=5000, help="Port to run the server on")
          args = parser.parse_args()
          login_manager.init_app(app)
          login_manager.login_view = "login"
          app.run(host="0.0.0.0", port=args.port)

      if __name__ == "__main__":
          run()
    '' else
      flaskScript;
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
  meta = { inherit description longDescription; };
}
