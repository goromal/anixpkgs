{
  callPackage,
  pytestCheckHook,
  buildPythonPackage,
}:
callPackage ../pythonPkgFromScript.nix {
  pname = "grafana_dash";
  version = "1.0.0";
  description = "Generate, sanitize, and lint Grafana dashboards.";
  script-file = ./dashgen.py;
  test-dir = ./tests;
  inherit pytestCheckHook buildPythonPackage;
  propagatedBuildInputs = [ ];
  checkPkgs = [ ];
  longDescription = "";
  subCmds = [
    "render"
    "sanitize"
    "lint"
  ];
}
