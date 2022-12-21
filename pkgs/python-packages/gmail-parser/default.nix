{ buildPythonPackage
, pythonOlder
, google-api-python-client
, pydrive2
, google-auth
, google-auth-oauthlib
, oauth2client
, html2text
, progressbar2
, pkg-src
}:
buildPythonPackage rec {
    pname = "gmail_parser";
    version = "0.0.0";
    disabled = pythonOlder "3.8";
    propagatedBuildInputs = [
        google-api-python-client
        pydrive2
        google-auth
        google-auth-oauthlib
        oauth2client
        html2text
        progressbar2
    ];
    src = pkg-src;
}
