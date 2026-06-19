{
  buildPythonPackage,
  fetchurl,
  jupyter-core,
  jupyter-client,
  jupyter-mimetypes,
  requests,
  traitlets,
  typing-extensions,
  websocket-client,
}:
buildPythonPackage rec {
  pname = "jupyter_kernel_client";
  version = "0.9.0";
  format = "wheel";
  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/7a/68/287315ba355aa93bda2e344de5febc45e6de1b47d8f4a5b69400b24cfdfd/jupyter_kernel_client-0.9.0-py3-none-any.whl";
    sha256 = "77acb8f2f738d97625d6bd01ee8cf21c4d59790b7ba464108712db3870416f20";
  };
  propagatedBuildInputs = [
    jupyter-core
    jupyter-client
    jupyter-mimetypes
    requests
    traitlets
    typing-extensions
    websocket-client
  ];
  doCheck = false;
  meta = {
    description = "Jupyter kernel client.";
    longDescription = ''
      [Repository](https://github.com/datalayer/jupyter-kernel-client)
    '';
  };
}
