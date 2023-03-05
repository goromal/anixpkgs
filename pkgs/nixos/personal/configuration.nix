{ config, pkgs, lib, ... }:
{
    imports = [
        ./hardware-configuration-inspiron.nix
        ./software-configuration.nix
    ];

    networking.hostName = "atorgesen-inspiron";

    nix.nixPath = [
        "nixos-config=/data/andrew/sources/anixpkgs/pkgs/nixos/personal/configuration.nix"
    ];

    system.stateVersion = "22.05";
}
