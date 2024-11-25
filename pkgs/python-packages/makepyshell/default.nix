{ callPackage, pytestCheckHook, buildPythonPackage, pkg-src }:
callPackage ../pythonPkgFromScript.nix {
  pname = "makepyshell";
  version = "1.0.0";
  description = "Generate a nix-shell file for Python development.";
  script-file = "${pkg-src}/makepyshell.py";
  inherit pytestCheckHook buildPythonPackage;
  propagatedBuildInputs = [ ];
  checkPkgs = [ ];
  longDescription = ''
    [Gist](https://gist.github.com/goromal/e64b6bdc8a176c38092e9bde4c434d31)
  '';
  autoGenUsageCmd = "--help";
}
