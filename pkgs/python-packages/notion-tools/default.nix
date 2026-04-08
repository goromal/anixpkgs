{
  buildPythonPackage,
  setuptools,
  requests,
  pkg-src,
}:
buildPythonPackage rec {
  pname = "notion-tools";
  version = "0.0.0";
  pyproject = true;
  build-system = [ setuptools ];
  src = pkg-src;
  propagatedBuildInputs = [
    requests
  ];
  doCheck = false;
  meta = {
    description = "Tools for interacting with Notion.";
    longDescription = ''
      [Repository](https://github.com/goromal/notion-tools)
    '';
  };
}
