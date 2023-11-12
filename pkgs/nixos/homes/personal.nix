{ config, pkgs, lib, ... }:
with import ../dependencies.nix { inherit config; }; {
  home.username = "andrew";
  home.homeDirectory = "/home/andrew";
  home.stateVersion = nixos-version;
  programs.home-manager.enable = true;

  # TODO Nix config setup? e.g., cachix
  # TODO remove this and homes directory; just atomize the components packaging

  imports = [
    ../components/base-pkgs.nix
    ../components/git.nix
    ../components/vim.nix
    ../components/vscodium.nix
    ../components/terminator.nix
    ../components/nautilus.nix
    ../components/gnome-wallpaper.nix
  ];

  mods.gnome-wallpaper.standalone = true;
  mods.gnome-wallpaper.homeDir = "/home/andrew";
}
