{ buildPythonPackage
, pkg-src
}:
buildPythonPackage rec {
    pname = "python_dokuwiki";
    version = "0.0.0";
    propagatedBuildInputs = [];
    doCheck = false;
    src = pkg-src;
}
