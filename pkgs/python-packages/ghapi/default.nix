{ lib
, buildPythonPackage
, fetchFromGitHub
, pytestCheckHook
, fastcore
, packaging
, pythonOlder
}:

buildPythonPackage rec {
  pname = "ghapi";
  version = "0.1.20";
  format = "setuptools";

  disabled = pythonOlder "3.8";

  src = fetchFromGitHub {
    owner = "fastai";
    repo = "ghapi";
    rev = version;
    sha256 = "sha256-Pry+qCHCt+c+uwkLaoTVUY1KblESj6kcNtMfGwK1rfk=";
  };

  propagatedBuildInputs = [
    fastcore
    packaging
  ];

  doCheck = false;

  pythonImportsCheck = [
    "ghapi"
  ];

  meta = {
    description = "Python interface to GitHub's API";
    longDescription = "https://github.com/fastai/ghapi";
  };
}
