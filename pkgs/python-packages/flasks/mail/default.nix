{
  buildPythonPackage,
  setuptools,
  flask,
  gmail-parser,
  python,
  pkg-src,
}:
let
  pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
in
buildPythonPackage rec {
  pname = "mail-ui";
  version = "0.0.1";
  pyproject = true;
  build-system = [ setuptools ];
  src = "${pkg-src}/mail";
  prePatch = ''
    mkdir -p $out/${pythonLibDir}/templates
    cp templates/main.html $out/${pythonLibDir}/templates/main.html
  '';
  propagatedBuildInputs = [
    flask
    gmail-parser
  ];
  meta = {
    description = "Flask UI for the GMail cleaner and email archive on the ATS machine.";
    longDescription = "Configure label->action cleaning rules, trigger cleaning runs with live progress and cancellation, and browse archived email as HTML.";
    autoGenUsageCmd = "--help";
  };
}
