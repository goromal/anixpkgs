{
  buildPythonPackage,
  fetchurl,
  jupyter-client,
  jupyter-server,
}:
buildPythonPackage rec {
  pname = "jupyter_server_nbmodel";
  version = "0.1.1a4";
  format = "wheel";
  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/5e/70/23edf6756dd2ae7c81ce5c2add66d986674d58072192152b80d417efbc4d/jupyter_server_nbmodel-0.1.1a4-py3-none-any.whl";
    sha256 = "f1c40906aaf98d6b66c3c9d5ebd6cad1b278d00c09d0a9227b0c15d972ec399a";
  };
  propagatedBuildInputs = [
    jupyter-client
    jupyter-server
  ];
  doCheck = false;
  meta = {
    description = "Jupyter server notebook model extension.";
    longDescription = ''
      [Repository](https://github.com/datalayer/jupyter-server-nbmodel)
    '';
  };
}
