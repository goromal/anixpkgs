{ config, pkgs, lib, ... }:
with pkgs;
with lib;
{
    imports = [
        ./base.nix
    ];

    networking.hostName = "atorgesen-pi4-test";

    nix.nixPath = [
        "nixos-config=/data/andrew/sources/anixpkgs/pkgs/nixos/raspberryPi/4/test.nix"
    ];

    system.stateVersion = "22.05";
}
