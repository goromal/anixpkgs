{
  pkgs,
  config,
  lib,
  ...
}:
with import ../dependencies.nix { system = pkgs.stdenv.hostPlatform.system; };
let
  cfg = config.mods.opts;
in
{
  home.packages =
    with pkgs;
    if (cfg.standalone == false) then
      [
        imagemagick
        maestral
        pciutils
        nixos-generators
      ]
    else
      [ ];
}
