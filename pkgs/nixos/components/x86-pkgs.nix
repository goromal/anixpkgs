{ pkgs, config, lib, ... }:
with pkgs;
with import ../dependencies.nix { inherit config; }; {
  home.packages = [ imagemagick maestral pciutils nixos-generators ];
}
