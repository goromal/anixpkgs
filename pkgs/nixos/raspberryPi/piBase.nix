# https://nix.dev/tutorials/installing-nixos-on-a-raspberry-pi
{ config, pkgs, lib, ... }:
with pkgs;
with lib;
{
    imports = [
        ../base.nix
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

    networking.networkmanager.enable = true;

    # TODO add some home-manager and basic git config

    # networking = {
    #     wireless = {
    #         enable = true;
    #         networks."LANtasia".psk = "2292238177";
    #         interfaces = [ "wlan0" ];
    #     };
    # };

    # Use 1GB of additional swap memory in order to not run out of memory
    # when installing lots of things while running other things at the same time.
    swapDevices = [ { device = "/swapfile"; size = 1024; } ];
}
