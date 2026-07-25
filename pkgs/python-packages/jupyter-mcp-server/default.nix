{
  buildPythonPackage,
  fetchurl,
  jupyter-kernel-client,
  jupyter-mcp-tools,
  jupyter-nbmodel-client,
  jupyter-server-nbmodel,
  jupyter-server-client,
  jupyter-server,
  tornado,
  traitlets,
  mcp,
  pydantic,
  uvicorn,
  click,
  fastapi,
  opentelemetry-api,
  opentelemetry-sdk,
}:
buildPythonPackage rec {
  pname = "jupyter_mcp_server";
  version = "1.0.2";
  format = "wheel";
  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/0e/5e/f306a728502f2d26988c76a882121dd1bb1a87c59e6db8b096a9a7b35903/jupyter_mcp_server-1.0.2-py3-none-any.whl";
    sha256 = "6be3c923fc6469094856e329dd593e4cbd4938cedb068b65697b3b1bc8543538";
  };
  propagatedBuildInputs = [
    jupyter-kernel-client
    jupyter-mcp-tools
    jupyter-nbmodel-client
    jupyter-server-nbmodel
    jupyter-server-client
    jupyter-server
    tornado
    traitlets
    mcp
    pydantic
    uvicorn
    click
    fastapi
    opentelemetry-api
    opentelemetry-sdk
  ];
  doCheck = false;
  meta = {
    description = "Monitor and control your Jupyter environment via Claude Code.";
    longDescription = ''
      [Repository](https://github.com/datalayer/jupyter-mcp-server)
    '';
    autoGenUsageCmd = "--help";
  };
}
