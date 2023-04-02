{ buildPythonPackage
, click
, wiki-tools
, google-api-python-client
, pydrive2
, google-auth
, google-auth-oauthlib
, oauth2client
, pkg-src
}:
buildPythonPackage rec {
  pname = "book-notes-sync";
  version = "0.0.0";
  src = pkg-src;
  propagatedBuildInputs = [
    click
    wiki-tools
    google-api-python-client
    pydrive2
    google-auth
    google-auth-oauthlib
    oauth2client
  ];
  doCheck = false;
}
