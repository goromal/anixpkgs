{
  buildPythonPackage,
  setuptools,
  flask,
  python,
}:
let
  pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
in
buildPythonPackage rec {
  pname = "intake_ui";
  version = "0.0.1";
  pyproject = true;
  build-system = [ setuptools ];
  src = ./.;
  prePatch = ''
    mkdir -p $out/${pythonLibDir}/templates
    cp ${./templates/main.html} $out/${pythonLibDir}/templates/main.html
  '';
  propagatedBuildInputs = [ flask ];
  meta = {
    description = "Flask UI for sending goromail messages on the ATS machine.";
    longDescription = "Provides a web interface for submitting messages to the goromail postfix maildir queue.";
    autoGenUsageCmd = "--help";
  };
}
