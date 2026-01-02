{ buildPythonPackage, flask, werkzeug, python }:
let pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
in buildPythonPackage rec {
  pname = "budget_ui";
  version = "0.0.0";
  src = ./.;
  prePatch = ''
    mkdir -p $out/${pythonLibDir}/templates
    cp ${./main.html} $out/${pythonLibDir}/templates/main.html
    cp ${./upload_config.html} $out/${pythonLibDir}/templates/upload_config.html
  '';
  propagatedBuildInputs = [ flask werkzeug ];
  meta = {
    description = "Provides an easy interface for doing the budget.";
    longDescription = "Must be run on a server with the `budget_report` tool.";
    autoGenUsageCmd = "--help";
  };
}
