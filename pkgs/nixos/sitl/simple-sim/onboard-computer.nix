{ config, pkgs, lib, ... }:
with pkgs;
with lib;
{
    imports = [
        ../../base.nix
    ];

    nix.nixPath = mkForce [
        "nixpkgs=${cleanSource ../../..}"
    ];

    networking.hostName = "onboard";

    environment.systemPackages = [
    ];
}
