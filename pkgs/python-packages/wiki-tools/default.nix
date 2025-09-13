{ buildPythonPackage, python-dokuwiki, click, pkg-src }:
buildPythonPackage rec {
  pname = "wiki-tools";
  version = "0.0.0";
  src = pkg-src;
  propagatedBuildInputs = [ python-dokuwiki click ];
  doCheck = false;
  meta = {
    description = "CLI tools for managing my wiki notes site.";
    longDescription = ''
      [Repository](https://github.com/goromal/wiki-tools)
    '';
    autoGenUsageCmd = "--help --wiki-user none --wiki-pass none";
    subCmds = [
      "get"
      "get-md"
      "get-rand-journal"
      "put"
      "put-dir"
      "put-md"
      "put-md-dir"
    ];
  };
}
