{
  buildPythonPackage,
  setuptools,
  flask,
  task-tools,
  python,
  pkg-src,
}:
let
  pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
in
buildPythonPackage rec {
  pname = "tasks_ui";
  version = "0.0.1";
  pyproject = true;
  build-system = [ setuptools ];
  src = "${pkg-src}/tasks_ui";
  prePatch = ''
    mkdir -p $out/${pythonLibDir}/templates
    cp templates/main.html $out/${pythonLibDir}/templates/main.html
  '';
  propagatedBuildInputs = [
    flask
    task-tools
  ];
  meta = {
    description = "Flask UI for task-tools on the ATS machine.";
    longDescription = "Provides a web interface for uploading tasks to Google Tasks using task-tools.";
    autoGenUsageCmd = "--help";
  };
}
