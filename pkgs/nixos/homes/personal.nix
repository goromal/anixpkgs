{ config, pkgs, lib, ... }:
with import ../dependencies.nix { inherit config; }; {
  home.username = "andrew";
  home.homeDirectory = "/home/andrew";
  home.stateVersion = nixos-version;
  programs.home-manager.enable = true;

  # TODO Nix config setup? e.g., cachix
  # TODO remove this and homes directory; just atomize the components packaging

  # $ nix-channel --add https://github.com/guibou/nixGL/archive/main.tar.gz nixgl && nix-channel --update
  # $ nix-env -iA nixgl.auto.nixGLDefault   # or replace `nixGLDefault` with your desired wrapper

  imports = [
    ../components/base-pkgs.nix
    ../components/x86-graphical-pkgs.nix
    ../components/x86-graphical-rec-pkgs.nix
  ];

  mods.x86-graphical.standalone = true;
  mods.x86-graphical.homeDir = "/home/andrew";
}
