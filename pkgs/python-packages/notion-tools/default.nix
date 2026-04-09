{
  buildPythonPackage,
  setuptools,
  requests,
  click,
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
    click
  ];
  doCheck = false;
  meta = {
    description = "Tools for interacting with Notion.";
    longDescription = ''
      [Repository](https://github.com/goromal/notion-tools)
    '';
    autoGenUsageCmd = "--help";
    subCmds = [
      "append"
      "annotate"
      "create-subpage"
      "get-blocks"
      "list-blocks"
      "list-subpages"
      "move-block"
      "set-title"
    ];
  };
}
