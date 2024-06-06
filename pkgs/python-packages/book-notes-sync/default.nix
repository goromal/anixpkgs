{ buildPythonPackage, click, wiki-tools, easy-google-auth, pkg-src }:
buildPythonPackage rec {
  pname = "book-notes-sync";
  version = "0.0.0";
  src = pkg-src;
  propagatedBuildInputs = [ click wiki-tools easy-google-auth ];
  doCheck = false;
  meta = {
    description =
      "Utility for syncing Google Play Books notes with my personal wiki.";
    longDescription = ''
      [Repository](https://github.com/goromal/book-notes-sync)
    '';
    autoGenUsageCmd = "--help";
  };
}
