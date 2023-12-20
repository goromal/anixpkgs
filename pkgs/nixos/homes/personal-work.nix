{ config, pkgs, lib, ... }:
with import ../dependencies.nix { inherit config; }; {
  home.username = "andrew";
  home.homeDirectory = "/home/andrew";
  home.stateVersion = nixos-version;
  programs.home-manager.enable = true;

  # TODO Nix config setup? e.g., cachix

  imports = [
    ../components/base-pkgs.nix
    ../components/base-dev-pkgs.nix
    ../components/x86-graphical-pkgs.nix
    ../components/x86-graphical-dev-pkgs.nix
  ];

  mods.x86-graphical.standalone = true;
  mods.x86-graphical.homeDir = "/home/andrew";
}
