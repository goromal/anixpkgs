{ pkgs, config, lib, ... }:
with import ../dependencies.nix { inherit config; }; {
  home.packages = [

    imagemagick
    maestral
    pciutils
    nixos-generators

  ];

}
