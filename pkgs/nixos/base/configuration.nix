{ config, pkgs, lib, ... }:
with pkgs;
with lib;
{
    imports = [
        ../base.nix
    ];

    networking.hostName = "base";
}
