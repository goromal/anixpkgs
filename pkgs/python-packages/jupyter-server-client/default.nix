{
  buildPythonPackage,
  fetchurl,
  requests,
  pydantic,
  typing-extensions,
}:
buildPythonPackage rec {
  pname = "jupyter_server_client";
  version = "0.1.1";
  format = "wheel";
  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/0f/2e/d22899abfdbc6fdd33860152f2108e6f377b11083e951bb67e6472e0247b/jupyter_server_client-0.1.1-py3-none-any.whl";
    sha256 = "5fc28099b95ea4b02e0bc85760507701c4c4315801897129e4b6c606582cf025";
  };
  propagatedBuildInputs = [
    requests
    pydantic
    typing-extensions
  ];
  doCheck = false;
  meta = {
    description = "Jupyter server client.";
    longDescription = ''
      [Repository](https://github.com/datalayer/jupyter-server-client)
    '';
  };
}
