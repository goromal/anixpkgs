{ config, pkgs, lib, ... }:
{
    imports = [
        ./hardware-configuration-inspiron.nix
        ./software-configuration.nix
    ];

    networking.hostName = "atorgesen-laptop";

    nix.nixPath = [
        "nixos-config=/data/andrew/sources/anixpkgs/pkgs/nixos/personal/configuration.nix"
    ];

    system.stateVersion = "22.05";

    # Essential Firmware
    hardware.enableRedistributableFirmware = lib.mkDefault true;
}
