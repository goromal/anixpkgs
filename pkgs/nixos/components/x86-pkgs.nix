{ pkgs, config, lib, ... }:
with pkgs;
with import ../dependencies.nix { inherit config; };
let cfg = config.mods.opts;
in {
  home.packages = if (cfg.standalone == false) then [
    imagemagick
    maestral
    pciutils
    nixos-generators
  ] else
    [ ];
}
