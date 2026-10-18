{
  buildPythonPackage,
  lib,
  setuptools,
  google-api-python-client,
  google-auth,
}:
buildPythonPackage {
  pname = "google-slides-mcp";
  version = "1.0.0";
  pyproject = true;
  build-system = [ setuptools ];
  propagatedBuildInputs = [
    google-api-python-client
    google-auth
  ];
  src = lib.cleanSource ./.;
  checkPhase = ''
    runHook preCheck
    python -m unittest discover -s tests -v
    runHook postCheck
  '';
  pythonImportsCheck = [ "google_slides_mcp_server" ];
  meta = {
    description = "Google Slides MCP server (stdlib stdio JSON-RPC over the Slides and Drive APIs).";
  };
}
