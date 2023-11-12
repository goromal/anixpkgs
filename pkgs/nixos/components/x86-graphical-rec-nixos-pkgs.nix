{ pkgs, config, lib, ... }:
with pkgs;
with import ../dependencies.nix { inherit config; }; {
  imports = [ ./x86-graphical-rec-pkgs.nix ];

  home.packages = [
    pavucontrol # compatible with pipewire-pulse
  ];
}
