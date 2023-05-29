{ buildPythonPackage
, click
, google-api-python-client
, google-auth
, google-auth-oauthlib
, oauth2client
, pkg-src
}:
buildPythonPackage rec {
  pname = "task-tools";
  version = "0.0.0";
  src = pkg-src;
  propagatedBuildInputs = [
    click
    google-api-python-client
    google-auth
    google-auth-oauthlib
    oauth2client
  ];
  doCheck = false;
}
