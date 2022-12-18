{ config, pkgs, lib, ... }:
with import ../dependencies.nix { inherit config; };
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
}
