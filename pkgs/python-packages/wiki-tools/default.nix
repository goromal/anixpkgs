{ buildPythonPackage
, python-dokuwiki
, click
, pkg-src
}:
buildPythonPackage rec {
  pname = "wiki-tools";
  version = "0.0.0";
  src = pkg-src;
  propagatedBuildInputs = [
    python-dokuwiki
    click
  ];
  doCheck = false;
}
