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
  pname = "sunset";
  version = "0.0.1";
  pyproject = true;
  build-system = [ setuptools ];
  src = ./.;
  prePatch = ''
    mkdir -p $out/${pythonLibDir}/templates
    cp ${./templates/main.html} $out/${pythonLibDir}/templates/main.html
  '';
  propagatedBuildInputs = [
    flask
  ];
  meta = {
    description = "Web UI to show and force-kill the running Dolphin emulator";
    longDescription = "Provides a browser-based interface at /sunset for checking whether the Dolphin emulator is running and force-killing it while leaving the launcher wrapper intact.";
    autoGenUsageCmd = "--help";
  };
}
