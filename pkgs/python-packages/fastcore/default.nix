{ lib
, buildPythonPackage
, fetchFromGitHub
, packaging
, pytestCheckHook
, pythonOlder
}:

buildPythonPackage rec {
  pname = "fastcore";
  version = "1.4.3";
  format = "setuptools";

  disabled = pythonOlder "3.8";

  src = fetchFromGitHub {
    owner = "fastai";
    repo = pname;
    rev = "refs/tags/${version}";
    sha256 = "sha256-3l5bELb5f/cvh4gF2kJZEX6kAK9achTerIIplMuesTk=";
  };

  propagatedBuildInputs = [
    packaging
  ];

  doCheck = false;

  pythonImportsCheck = [
    "fastcore"
  ];

  meta = {
    description = "Python module for Fast AI";
    longDescription = "https://github.com/fastai/fastcore";
  };
}
