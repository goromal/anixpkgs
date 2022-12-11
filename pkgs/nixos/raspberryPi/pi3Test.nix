{ config, pkgs, lib, ... }:
with pkgs;
with lib;
{
    imports = [
        ./pi3Base.nix
    ];

    networking.hostName = "atorgesen-pi";
}