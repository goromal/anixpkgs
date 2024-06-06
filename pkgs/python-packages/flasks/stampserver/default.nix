{ buildPythonPackage, flask, flask_login, flask_wtf, wtforms, werkzeug
, writeShellScript, python }:
let pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
in buildPythonPackage rec {
  pname = "stampserver";
  version = "0.0.0";
  src = ./.;
  prePatch = ''
    mkdir -p $out/${pythonLibDir}/templates
    cp ${./index.html} $out/${pythonLibDir}/templates/index.html
    cp ${./login.html} $out/${pythonLibDir}/templates/login.html
  '';
  propagatedBuildInputs = [ flask flask_login flask_wtf wtforms werkzeug ];
  meta = {
    description =
      "Provides an interface for stamping metadata on PNGs and MP4s.";
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
