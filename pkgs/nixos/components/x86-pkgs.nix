{ pkgs, config, lib, ... }:
with pkgs;
with import ../dependencies.nix { inherit config; };
let cfg = config.mods.opts;
in {
  home.packages = lib.mkIf (cfg.standalone == false) [
    imagemagick
    maestral
    pciutils
    nixos-generators
  ];
}
