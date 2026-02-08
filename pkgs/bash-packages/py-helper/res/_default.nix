{
  buildPythonPackage,
  setuptools,
  lib,
  # ADD deps
}:
buildPythonPackage rec {
  pname = "REPLACEME";
  version = "0.0.0";
  pyproject = true;
  build-system = [ setuptools ];
  src = lib.cleanSource ./.;
  propagatedBuildInputs = [
    # ADD deps
  ];
  doCheck = false;
}
