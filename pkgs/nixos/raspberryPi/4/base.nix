# https://nix.dev/tutorials/installing-nixos-on-a-raspberry-pi
{ config, pkgs, lib, ... }:
with pkgs;
with lib;
{
    imports = [
        "${fetchTarball "https://github.com/NixOS/nixos-hardware/archive/936e4649098d6a5e0762058cb7687be1b2d90550.tar.gz" }/raspberry-pi/4"
        ../base.nix
    ];

    # Enable GPU acceleration
    hardware.raspberry-pi."4".fkms-3d.enable = true;
}
