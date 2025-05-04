{ pkgs, config, lib, ... }:
with import ../dependencies.nix;
let cfg = config.mods.opts;
in {
  home.packages = ([
    anixpkgs.trafficsim
    anixpkgs.la-quiz
    (anixpkgs.play.override { standalone-opt = cfg.standalone; })
  ] ++ (if cfg.standalone == false then [
    pkgs.sage
    pkgs.pavucontrol # compatible with pipewire-pulse
  ] else
    [ ]));
}
