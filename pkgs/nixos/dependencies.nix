let
  nixos-version = (builtins.readFile ../../NIXOS_VERSION);
  anixpkgs-version = (builtins.readFile ../../ANIX_VERSION);
in rec {
  local-build = false;
  inherit nixos-version; # Should match the channel in <nixpkgs>
  inherit anixpkgs-version;
  anixpkgs-src = if local-build then
    ../../default.nix
  else
    (builtins.fetchTarball
      "https://github.com/goromal/anixpkgs/archive/refs/tags/v${anixpkgs-version}.tar.gz");
  anixpkgs = import anixpkgs-src { };
  unstable = import (builtins.fetchTarball
    "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz") { };
}
