{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  poetry-core,
  colored,
  invoke,
  coverage,
  pytest,
  pytest-benchmark,
  pytest-xdist,
  # , pytestCheckHook
  pythonOlder,
}:

buildPythonPackage rec {
  pname = "syrupy";
  version = "4.0.1";
  format = "pyproject";

  disabled = pythonOlder "3.8";

  src = fetchFromGitHub {
    owner = "tophat";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-BL1Z1hPMwU1duAZb3ZTWWKS/XGv8RJ6/4YoBhktd5NE=";
  };

  nativeBuildInputs = [ poetry-core ];

  propagatedBuildInputs = [
    colored
    invoke
    coverage
    pytest
    pytest-benchmark
    pytest-xdist
  ];

  doCheck = false;
}
