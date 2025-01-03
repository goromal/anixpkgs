{ lib, buildPythonPackage, fetchPypi }:

buildPythonPackage rec {
  version = "0.3.5";
  pname = "sym";

  src = fetchPypi {
    inherit pname version;
    sha256 = "854ddd18f0a1f94c9590012e50a139b499b407c90e9ebd407c40285627784ab8";
  };

  propagatedBuildInputs = [ ];

  # no tests
  doCheck = false;

  pythonImportsCheck = [ ];

  meta = with lib; {
    homepage = "https://pypi.org/project/sym/0.3.5/#description";
    description =
      "*nified wrapper to some symbolic manipulation libraries in Python.";
    longDescription = ''
      This is an open-source package that I maintain the build of for my convenience.

      [Homepage](https://pypi.org/project/sym/0.3.5/#description)
    '';
  };
}
