{ buildPythonPackage, pytestCheckHook, click, easy-google-auth, pkg-src }:
buildPythonPackage rec {
  pname = "photos-tools";
  version = "0.0.0";
  src = pkg-src;
  propagatedBuildInputs = [ click easy-google-auth ];
  doCheck = true;
  checkInputs = [ pytestCheckHook ];
  meta = {
    description = "CLI tools for managing Google Photos.";
    longDescription = ''
      [Repository](https://github.com/goromal/photos-tools)
    '';
    autoGenUsageCmd = "--help";
    subCmds = [ "clean" ];
  };
}
