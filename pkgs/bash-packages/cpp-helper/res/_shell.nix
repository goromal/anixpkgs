let
  pkgs = import (fetchTarball
    ("https://github.com/goromal/anixpkgs/archive/refs/tags/vREPLACEME.tar.gz"))
    { };
in with pkgs;
mkShell {
  nativeBuildInputs = [ cmake ];
  buildInputs = [
    # ADD deps
  ];
}
