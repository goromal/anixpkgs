{
  buildPythonPackage,
  setuptools,
  pytestCheckHook,
  flask,
  werkzeug,
  python,
  pkg-src,
}:
let
  pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
in
buildPythonPackage rec {
  pname = "nexus-ui";
  version = "0.0.1";
  pyproject = true;
  build-system = [ setuptools ];
  src = "${pkg-src}/nexus";
  prePatch = ''
    mkdir -p $out/${pythonLibDir}/templates
    cp templates/main.html $out/${pythonLibDir}/templates/main.html
  '';
  propagatedBuildInputs = [
    flask
    werkzeug
  ];
  nativeCheckInputs = [ pytestCheckHook ];
  meta = {
    description = "LAN hub UI for machine status and bulk anix-upgrade";
    longDescription = "Discovers opted-in LAN machines over mDNS, links to each machine's landing page, shows online status and versions, and fans out anix-upgrade runs to selected machines.";
    autoGenUsageCmd = "--help";
  };
}
