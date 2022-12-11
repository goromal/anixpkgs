# https://nix.dev/tutorials/installing-nixos-on-a-raspberry-pi
{ config, pkgs, lib, ... }:
with pkgs;
with lib;
{
    imports = [
        ../base.nix
    ];

    fileSystems = {
        "/" = {
            device = "/dev/disk/by-label/NIXOS_SD";
            fsType = "ext4";
            options = [ "noatime" ];
        };
    };

    networking = {
        wireless = {
            enable = true;
            networks."LANtasia".psk = "2292238177";
            interfaces = [ "wlan0" ];
        };
    };
}
