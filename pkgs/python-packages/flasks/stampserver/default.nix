{
  buildPythonPackage,
  setuptools,
  flask,
  flask-login,
  flask-wtf,
  wtforms,
  werkzeug,
  pillow,
  opencv4,
  writeShellScript,
  python,
}:
let
  pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
in
buildPythonPackage rec {
  pname = "stampserver";
  version = "0.0.0";
  pyproject = true;
  build-system = [ setuptools ];
  src = ./.;
  prePatch = ''
    mkdir -p $out/${pythonLibDir}/templates
    cp ${./index.html} $out/${pythonLibDir}/templates/index.html
    cp ${./login.html} $out/${pythonLibDir}/templates/login.html
  '';
  propagatedBuildInputs = [
    flask
    flask-login
    flask-wtf
    wtforms
    werkzeug
    pillow
    opencv4
  ];
  meta = {
    description = "Provides an interface for stamping metadata on PNGs and MP4s.";
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
