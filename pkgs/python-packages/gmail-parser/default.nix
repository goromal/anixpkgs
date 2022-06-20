{ buildPythonPackage
, pythonOlder
, google-api-python-client
, pydrive
, google-auth
, oauth2client
}:
buildPythonPackage rec {
    pname = "gmail_parser";
    version = "0.0.0";
    disabled = pythonOlder "3.8";
    propagatedBuildInputs = [
        google-api-python-client
        pydrive
        google-auth
        oauth2client
    ];
    src = ../../../../gmail-parser/.;
}
