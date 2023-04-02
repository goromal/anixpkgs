{ config, pkgs, lib, ... }:
with pkgs;
with lib;
with import ../../dependencies.nix { inherit config; };
{
    imports = [
        ./base.nix
        ../../../python-packages/flasks/rankserver/module.nix
    ];
    
    networking.hostName = "rankserver-pi4";
    
    nix.nixPath = [
        "nixos-config=/data/andrew/sources/anixpkgs/pkgs/nixos/pi/4/rankserver.nix"
    ];
    
    system.stateVersion = "22.05";
    
    services.rankserver = {
        enable = true;
        package = anixpkgs.rankserver;
        dataDir = "rankables";
        port = 4018;
        openFirewall = true;
    };
}
