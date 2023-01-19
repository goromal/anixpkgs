{ buildPythonPackage
, fetchPypi
, pythonOlder
, colorama
, requests
, lxml
, pkg-src
}:
buildPythonPackage rec {
    pname = "scrape";
    version = "0.0.1";
    disabled = pythonOlder "3.6";
    propagatedBuildInputs = [
        colorama
        requests
        lxml
    ];
    src = pkg-src;
}
