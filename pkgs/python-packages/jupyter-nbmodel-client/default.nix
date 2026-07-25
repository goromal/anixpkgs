{
  buildPythonPackage,
  fetchurl,
  jupyter-ydoc,
  nbformat,
  pycrdt,
  requests,
  websockets,
}:
buildPythonPackage rec {
  pname = "jupyter_nbmodel_client";
  version = "0.14.7";
  format = "wheel";
  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/3d/61/5d6ada9177f164f3ca0394af899d09a7bb82b6ba9bb5f1d559a9d9f53758/jupyter_nbmodel_client-0.14.7-py3-none-any.whl";
    sha256 = "ff9371378608dd46f5cb58e394493aa6bde4efcbabbcb988fc331f55b5b7cef3";
  };
  propagatedBuildInputs = [
    jupyter-ydoc
    nbformat
    pycrdt
    requests
    websockets
  ];
  doCheck = false;
  meta = {
    description = "Jupyter notebook model client.";
    longDescription = ''
      [Repository](https://github.com/datalayer/jupyter-nbmodel-client)
    '';
  };
}
