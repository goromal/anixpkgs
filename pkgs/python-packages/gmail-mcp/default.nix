{
  buildPythonPackage,
  setuptools,
  gmail-parser,
  pkg-src,
}:
buildPythonPackage {
  pname = "gmail-mcp";
  version = "0.0.1";
  pyproject = true;
  build-system = [ setuptools ];
  propagatedBuildInputs = [ gmail-parser ];
  src = "${pkg-src}/mcp";
  checkPhase = ''
    runHook preCheck
    python -m unittest discover -s tests -v
    runHook postCheck
  '';
  pythonImportsCheck = [ "gmail_mcp_server" ];
  meta = {
    description = "gmail MCP server (stdlib stdio JSON-RPC over gmail_parser's GMailCorpus).";
  };
}
