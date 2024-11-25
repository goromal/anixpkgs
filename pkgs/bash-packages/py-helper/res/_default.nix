{ buildPythonPackage, lib
# ADD deps
}:
buildPythonPackage rec {
  pname = "REPLACEME";
  version = "0.0.0";
  src = lib.cleanSource ./.;
  propagatedBuildInputs = [
    # ADD deps
  ];
  doCheck = false;
}
