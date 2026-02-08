let
  pkgs = import (fetchTarball (
    "https://github.com/goromal/anixpkgs/archive/refs/tags/vREPLACEME.tar.gz"
  )) { };
in
with pkgs;
mkShell {
  nativeBuildInputs = [
    cpp-helper
    cmake
  ];
  buildInputs = [
    # ADD deps
  ];
}
