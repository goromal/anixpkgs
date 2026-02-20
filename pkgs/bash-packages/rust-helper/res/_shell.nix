let
  pkgs = import (fetchTarball (
    "https://github.com/goromal/anixpkgs/archive/refs/tags/vREPLACEME.tar.gz"
  )) { };
in
pkgs.mkShell {
  buildInputs = [
    pkgs.cargo
    pkgs.rustc
    pkgs.rustfmt
  ];
}
