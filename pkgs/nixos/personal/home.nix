{ config, pkgs, lib, ... }:
with import ../dependencies.nix { inherit config; };
{
    home.username = "andrew";
    home.homeDirectory = "/home/andrew";
    home.stateVersion = nixos-version;
    programs.home-manager.enable = true;

    # TODO Nix config setup? e.g., cachix

    imports = [
        ../home-mods/base-anixpkgs.nix
        ../home-mods/git.nix
        ../home-mods/vim.nix
        ../home-mods/vscodium.nix
        ../home-mods/terminator.nix
        ../home-mods/nautilus.nix
        ../home-mods/gnome-wallpaper.nix
    ];

    mods.gnome-wallpaper.standalone = true;
    mods.gnome-wallpaper.homeDir = "/home/andrew";
}
