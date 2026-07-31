{
  buildPythonPackage,
  setuptools,
  pkg-src,
}:
buildPythonPackage {
  pname = "folio-mcp";
  version = "0.0.1";
  pyproject = true;
  build-system = [ setuptools ];
  src = "${pkg-src}/mcp";
  checkPhase = ''
    runHook preCheck
    python -m unittest discover -s tests -v
    runHook postCheck
  '';
  pythonImportsCheck = [ "folio_mcp_server" ];
  meta = {
    description = "folio MCP server (stdlib stdio JSON-RPC over the folio backend API).";
  };
}
