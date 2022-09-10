{ buildPythonPackage
, fetchPypi
, pythonOlder
, colorama
, requests
, lxml
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
    src = builtins.fetchGit (import ./src.nix);
}
