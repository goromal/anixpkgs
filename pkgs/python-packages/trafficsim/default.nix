{ callPackage, pytestCheckHook, buildPythonPackage, numpy, matplotlib, geometry
, pysignals, pkg-src }:
callPackage ../pythonPkgFromScript.nix {
  pname = "trafficsim";
  version = "1.0.0";
  description = "Simulate traffic.";
  script-file = "${pkg-src}/traffic.py";
  inherit pytestCheckHook buildPythonPackage;
  propagatedBuildInputs = [ numpy matplotlib geometry pysignals ];
  checkPkgs = [ ];
  longDescription = ''
    [Gist](https://gist.github.com/goromal/c37629235750b65b9d0ec0e17456ee96)

    Simple traffic simulator on a circular road. Cars have two control objectives: maintain a consistent distance between cars and maintain a consistent car speed.
  '';
  autoGenUsageCmd = "--help";
}
