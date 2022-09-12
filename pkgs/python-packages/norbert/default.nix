{ buildPythonPackage
, fetchPypi
, pythonOlder
, scipy
}:
buildPythonPackage rec {
    pname = "norbert";
    version = "0.2.1";
    disabled = pythonOlder "3.6";
    propagatedBuildInputs = [
        scipy
    ];
    src = fetchPypi {
        inherit pname version;
        sha256 = "bd4cbc2527f0550b81bf4265c1a64b352cab7f71e4e3c823d30b71a7368de74e";
    };
}
