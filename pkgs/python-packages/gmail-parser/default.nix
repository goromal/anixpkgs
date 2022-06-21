{ buildPythonPackage
, pythonOlder
, google-api-python-client
, pydrive
, google-auth
, google-auth-oauthlib
, oauth2client
, html2text
, progressbar2
}:
buildPythonPackage rec {
    pname = "gmail_parser";
    version = "0.0.0";
    disabled = pythonOlder "3.8";
    propagatedBuildInputs = [
        google-api-python-client
        pydrive
        google-auth
        google-auth-oauthlib
        oauth2client
        html2text
        progressbar2
    ];
    src = builtins.fetchGit (import ./src.nix);
}
