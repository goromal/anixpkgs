{ buildPythonPackage, setuptools, flask, easy-google-auth, gmail-parser
, writeShellScript, python }:
let pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
in buildPythonPackage rec {
  pname = "authui";
  version = "0.0.0";
  pyproject = true;
  build-system = [ setuptools ];
  src = ./.;
  prePatch = ''
    mkdir -p $out/${pythonLibDir}/templates
    cp ${./index.html} $out/${pythonLibDir}/templates/index.html
  '';
  propagatedBuildInputs = [ flask easy-google-auth gmail-parser ];
  meta = {
    description =
      "Provides an easy interface for remotely refreshing credentials.";
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
