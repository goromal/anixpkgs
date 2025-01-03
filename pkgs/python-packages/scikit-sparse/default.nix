{ lib, buildPythonPackage, fetchPypi, numpy, cython, suitesparse }:

buildPythonPackage rec {
  version = "0.4.15";
  pname = "scikit_sparse";

  src = fetchPypi {
    inherit pname version;
    sha256 = "a0b1ef1bbe9e28e5c6d2838c63c62e094a8098d11a736771edac55ccc5f9eabe";
  };

  propagatedBuildInputs = [ numpy cython suitesparse ];

  # no tests
  doCheck = false;

  pythonImportsCheck = [ ];

  meta = with lib; {
    homepage = "https://pypi.org/project/scikit-sparse/#description";
    description = "Sparse matrix tools.";
    longDescription = ''
      This is an open-source package that I maintain the build of for my convenience.

      [Homepage](https://pypi.org/project/scikit-sparse/#description)
    '';
  };
}
