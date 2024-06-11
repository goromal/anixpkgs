{ config }:
let
  nixos-version = (builtins.readFile ../../NIXOS_VERSION);
  anixpkgs-version = (builtins.readFile ../../ANIX_VERSION);
in rec {
  local-build = true;
  inherit nixos-version; # Should match the channel in <nixpkgs>
  nixos-state = "22.05"; # nixos-version;
  homem-state = "22.05"; # nixos-version;
  inherit anixpkgs-version;
  anixpkgs = import (if local-build then
    ../../default.nix
  else
    (builtins.fetchTarball
      "https://github.com/goromal/anixpkgs/archive/refs/tags/v${anixpkgs-version}.tar.gz"))
    { };
  unstable = import (builtins.fetchTarball
    "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz") { };
}
