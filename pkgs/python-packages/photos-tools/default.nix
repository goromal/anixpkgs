{ buildPythonPackage, setuptools, click, easy-google-auth, pkg-src }:
buildPythonPackage rec {
  pname = "photos-tools";
  version = "0.0.0";
  pyproject = true;
  build-system = [ setuptools ];
  src = pkg-src;
  propagatedBuildInputs = [ click easy-google-auth ];
  doCheck = false;
  meta = {
    description = "CLI tools for managing Google Photos.";
    longDescription = ''
      [Repository](https://github.com/goromal/photos-tools)

      For your photos management, follow these steps:

      1. Favorite *only* the media that you would like to "thin out"
      2. On a computer with space, run the clean method
      3. Move the whole Favorites directory to the trash
    '';
    autoGenUsageCmd = "--help";
    subCmds = [ "clean" ];
  };
}
