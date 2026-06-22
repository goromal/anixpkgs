{
  buildPythonPackage,
  setuptools,
  flask,
  flask-login,
  flask-wtf,
  wtforms,
  werkzeug,
  requests,
  websocket-client,
  python,
}:
let
  pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
in
buildPythonPackage rec {
  pname = "cozy";
  version = "0.0.0";
  pyproject = true;
  build-system = [ setuptools ];
  src = ./.;
  prePatch = ''
    mkdir -p $out/${pythonLibDir}/templates
    mkdir -p $out/${pythonLibDir}/static
    cp ${./templates/index.html} $out/${pythonLibDir}/templates/index.html
    cp ${./templates/login.html} $out/${pythonLibDir}/templates/login.html
    cp ${./tv.svg} $out/${pythonLibDir}/static/tv.svg
  '';
  propagatedBuildInputs = [
    flask
    flask-login
    flask-wtf
    wtforms
    werkzeug
    requests
    websocket-client
  ];
  meta = {
    description = "One-pager UI for generating images with ComfyUI workflows.";
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
