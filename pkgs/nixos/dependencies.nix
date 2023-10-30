{ config }:
let
  nixos-version = (builtins.readFile ../../NIXOS_VERSION);
  anix-version = (builtins.readFile ../../ANIX_VERSION);
in rec {
  local-build = false;
  inherit nixos-version; # Should match the channel in <nixpkgs>
  nixos-state = nixos-version;
  homem-state = nixos-version;
  inherit anix-version;
  anixpkgs = import (if local-build then
    ../../default.nix
  else
    (builtins.fetchTarball
      "https://github.com/goromal/anixpkgs/archive/refs/tags/v${anix-version}.tar.gz"))
    { };
  unstable = import (builtins.fetchTarball
    "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz") { };
}
