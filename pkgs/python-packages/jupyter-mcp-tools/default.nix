{
  buildPythonPackage,
  fetchurl,
  jupyter-server,
  aiohttp,
}:
buildPythonPackage rec {
  pname = "jupyter_mcp_tools";
  version = "0.1.6";
  format = "wheel";
  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/a1/f4/28e9cbdd05d3146d5adedc474f64a2d669c21b0e672d09b0885a1cc7c85a/jupyter_mcp_tools-0.1.6-py3-none-any.whl";
    sha256 = "45cb18658d5853a62faccd5e8ea17becc3a1850482a43c49a9e4bb2c854effd7";
  };
  propagatedBuildInputs = [
    jupyter-server
    aiohttp
  ];
  doCheck = false;
  meta = {
    description = "Jupyter MCP tools (JupyterLab extension and MCP tool implementations).";
    longDescription = ''
      [Repository](https://github.com/datalayer/jupyter-mcp-tools)
    '';
  };
}
