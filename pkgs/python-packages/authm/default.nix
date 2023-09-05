{ callPackage, pytestCheckHook, buildPythonPackage, click, colorama
, easy-google-auth, gmail-parser, task-tools, wiki-tools, book-notes-sync }:
callPackage ../pythonPkgFromScript.nix {
  pname = "authm";
  version = "1.0.0";
  description = "Manage secrets.";
  script-file = ./authm.py;
  inherit pytestCheckHook buildPythonPackage;
  propagatedBuildInputs = [
    click
    colorama
    easy-google-auth
    gmail-parser
    task-tools
    wiki-tools
    book-notes-sync
  ];
  checkPkgs = [ ];
  longDescription = ''
    ```
    Usage: authm [OPTIONS] COMMAND [ARGS]...

      Manage secrets.

    Options:
      --help  Show this message and exit.

    Commands:
      refresh   Refresh all auth tokens one-by-one.
      validate  Validate the secrets files present on the filesystem.
    ```
  '';
}
