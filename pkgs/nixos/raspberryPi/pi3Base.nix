# https://nix.dev/tutorials/installing-nixos-on-a-raspberry-pi
{ config, pkgs, lib, ... }:
with pkgs;
with lib;
{
    imports = [
        ./piBase.nix
    ];

    boot.loader.grub.enable = false;
    boot.kernelParams = ["cma=256M"];
    boot.loader.raspberryPi.enable = true;
    boot.loader.raspberryPi.version = 3;
    boot.loader.raspberryPi.uboot.enable = true;
    boot.loader.raspberryPi.firmwareConfig = ''
        gpu_mem=256
    '';
}