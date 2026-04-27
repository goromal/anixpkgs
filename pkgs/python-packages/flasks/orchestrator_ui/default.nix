{
  buildPythonPackage,
  setuptools,
  flask,
  grpcio,
  aapis-py,
  python,
}:
let
  pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
in
buildPythonPackage rec {
  pname = "orchestrator_ui";
  version = "0.0.0";
  pyproject = true;
  build-system = [ setuptools ];
  src = ./.;
  prePatch = ''
    mkdir -p $out/${pythonLibDir}/templates
    cp ${./templates/main.html} $out/${pythonLibDir}/templates/main.html
  '';
  propagatedBuildInputs = [
    flask
    grpcio
    aapis-py
  ];
  meta = {
    description = "Web UI for managing orchestrator jobs";
    longDescription = "Provides a browser-based interface equivalent to the otrigger CLI.";
    autoGenUsageCmd = "--help";
  };
}
