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
  pname = "sunset";
  version = "0.0.1";
  pyproject = true;
  build-system = [ setuptools ];
  src = "${pkg-src}/sunset";
  prePatch = ''
    mkdir -p $out/${pythonLibDir}/templates
    cp templates/main.html $out/${pythonLibDir}/templates/main.html
  '';
  propagatedBuildInputs = [
    flask
  ];
  meta = {
    description = "Web UI to monitor Dolphin and PCSX2 and stop running games";
    longDescription = "Provides a browser-based interface at /sunset to monitor Dolphin and PCSX2, gracefully stop PCSX2, or force-quit emulators while leaving play running to sync memory cards.";
    autoGenUsageCmd = "--help";
  };
}
