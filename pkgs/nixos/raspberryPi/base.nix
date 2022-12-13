# https://nix.dev/tutorials/installing-nixos-on-a-raspberry-pi
{ config, pkgs, lib, ... }:
with pkgs;
with lib;
with callPackage import ../dependencies.nix { inherit config; };
{
    imports = [
        ../base.nix
    ];

    nix.nixPath = [
        "anixpkgs=/data/andrew/sources/anixpkgs"
    ];

    environment.systemPackages = [
        libraspberrypi
    ];

    fileSystems = {
        "/" = {
            device = "/dev/disk/by-label/NIXOS_SD";
            fsType = "ext4";
            options = [ "noatime" ];
        };
    };

    home-manager.users.andrew = {
        home.packages = [
            anixpkgs.color-prints
            anixpkgs.git-cc
            anixpkgs.fix-perms
            anixpkgs.secure-delete
            anixpkgs.sunnyside
        ];
    };

    # Use 1GB of additional swap memory in order to not run out of memory
    # when installing lots of things while running other things at the same time.
    swapDevices = [ { device = "/swapfile"; size = 1024; } ];
}
