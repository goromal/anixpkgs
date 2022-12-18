# https://nix.dev/tutorials/installing-nixos-on-a-raspberry-pi
{ config, pkgs, lib, ... }:
with pkgs;
with lib;
let hwArch = fetchTarball "https://github.com/NixOS/nixos-hardware/archive/c9c1a5294e4ec378882351af1a3462862c61cb96.tar.gz";
in {
    imports = [
        "${hwArch}/raspberry-pi/4"
        ../base.nix
    ];

    boot.kernelPackages = mkForce linuxPackages_rpi4;

    # Enable GPU acceleration
    hardware.raspberry-pi."4".fkms-3d.enable = true;
}
