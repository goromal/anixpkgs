{
  buildPythonPackage,
  setuptools,
  flask,
  python,
  pkg-src,
}:
let
  pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
in
buildPythonPackage rec {
  pname = "anix-upgrade-ui";
  version = "0.0.1";
  pyproject = true;
  build-system = [ setuptools ];
  src = "${pkg-src}/anix-upgrade-ui";
  prePatch = ''
    mkdir -p $out/${pythonLibDir}/templates
    cp templates/main.html $out/${pythonLibDir}/templates/main.html
  '';
  propagatedBuildInputs = [
    flask
  ];
  meta = {
    description = "Web UI for triggering anix-upgrade";
    longDescription = "Provides a browser-based interface for running anix-upgrade and viewing its output.";
    autoGenUsageCmd = "--help";
  };
}
