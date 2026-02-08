{
  python,
  lib,
  fetchPypi,
  buildPythonPackage,
  setuptools,
  fetchurl,
  pythonOlder,
  black,
  jinja2,
}:
let
  symforce-sym = buildPythonPackage rec {
    version = "0.9.0";
    pname = "symforce-sym";
    pyproject = true;
    build-system = [ setuptools ];
    disabled = pythonOlder "3.11";

    src = fetchPypi {
      inherit pname version;
      sha256 = "2eecfa0b1d9a2544be832e9842c2b7a02859ff4259f8214a5fce7f79c2064347";
    };

    propagatedBuildInputs = [ ];
    doCheck = false;
    pythonImportsCheck = [ ];
  };
in
buildPythonPackage rec {
  version = "0.9.0";
  pname = "symforce";
  format = "wheel";
  disabled = pythonOlder "3.11";

  # https://pypi.org/project/symforce/
  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/be/c3/5b36a2b2bb2085f3b9f5cd4d4c7708f7ac52911b80ea849a847921d2e02e/symforce-0.9.0-cp311-cp311-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
    sha256 = "ea67d7cdec1753cc77fba12131413f7a53da90a0911bd0863f0c74256b9c6067";
    hash = "";
  };

  propagatedBuildInputs = [
    symforce-sym
    black
    jinja2
  ];

  doCheck = false;

  pythonImportsCheck = [ ];

  meta = with lib; {
    homepage = "https://symforce.org/";
    description = "SymForce is a fast symbolic computation and code generation library for robotics applications like computer vision, state estimation, motion planning, and controls.";
    longDescription = ''
      This library was built and is maintained by Skydio.

      [Homepage](https://symforce.org/)
    '';
  };
}
