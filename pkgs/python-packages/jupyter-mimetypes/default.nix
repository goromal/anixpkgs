{
  buildPythonPackage,
  fetchurl,
  pyarrow,
  typing-extensions,
}:
buildPythonPackage rec {
  pname = "jupyter_mimetypes";
  version = "0.2.0";
  format = "wheel";
  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/72/45/cb4671e13fed39f721066ad1a00714d4b607982b8d3e97a25f836198d1df/jupyter_mimetypes-0.2.0-py3-none-any.whl";
    sha256 = "e6dcd989258e3fc944365b656d9173191517e0e393bd878e97ce500e5b388527";
  };
  propagatedBuildInputs = [
    pyarrow
    typing-extensions
  ];
  doCheck = false;
  meta = {
    description = "Jupyter MIME types utilities.";
    longDescription = ''
      [Repository](https://github.com/datalayer/jupyter-mimetypes)
    '';
  };
}
