{ buildPythonPackage, pythonOlder, google-api-python-client, google-auth
, google-auth-oauthlib, oauth2client, pkg-src }:
buildPythonPackage rec {
  pname = "easy_google_auth";
  version = "0.0.0";
  disabled = pythonOlder "3.8";
  propagatedBuildInputs =
    [ google-api-python-client google-auth google-auth-oauthlib oauth2client ];
  src = pkg-src;
  meta = {
    description =
      "Convenience library for abstracting away Google API authorization protocols for my various Python libraries that use it.";
    longDescription = ''
      [Repository](https://github.com/goromal/easy-google-auth)

      Used as the authorization source for:

      - [gmail-parser](./gmail-parser.md)
      - [task-tools](./task-tools.md)
      - [book-notes-sync](./book-notes-sync.md)
    '';
  };
}
