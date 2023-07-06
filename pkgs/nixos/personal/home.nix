{ config, pkgs, lib, ... }:
with import ../dependencies.nix { inherit config; };
{
    home.username = "andrew";
    home.homeDirectory = "/home/${username}";
    home.stateVersion = nixos-version;
    programs.home-manager.enable = true;

    imports = [
        ../home-mods/base-anixpkgs.nix
        ../home-mods/git.nix
        ../home-mods/vim.nix
        ../home-mods/vscodium.nix
        ../home-mods/terminator.nix
        ../home-mods/nautilus.nix
        ../home-mods/gnome-wallpaper.nix
    ];

    mods.vscodium.package = unstable.vscodium;
    mods.gnome-wallpaper.standalone = true;
}
