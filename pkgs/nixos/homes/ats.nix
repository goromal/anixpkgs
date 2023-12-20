{ config, pkgs, lib, ... }:
with import ../dependencies.nix { inherit config; }; {
  home.username = "andrew";
  home.homeDirectory = "/home/andrew";
  home.stateVersion = nixos-version;
  programs.home-manager.enable = true;

  imports =
    [ ../components/base-pkgs.nix ../components/x86-graphical-pkgs.nix ];

  mods.x86-graphical.standalone = true;
  mods.x86-graphical.homeDir = "/home/andrew";
}
