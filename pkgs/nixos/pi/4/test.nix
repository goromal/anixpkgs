{ config, pkgs, lib, ... }:
with pkgs;
with lib;
with import ../../dependencies.nix { inherit config; };
{
    imports = [
        ./base.nix
        ../../../python-packages/flasks/smfserver/module.nix
        ../../../python-packages/flasks/url2mp4/module.nix
    ];

    networking.hostName = "atorgesen-pi4-test";

    nix.nixPath = [
        "nixos-config=/data/andrew/sources/anixpkgs/pkgs/nixos/pi/4/test.nix"
    ];

    system.stateVersion = "22.05";

    services.smfserver = {
        enable = true;
        package = anixpkgs.flask-smfserver;
        port = 4050;
    };

    services.url2mp4server = {
        enable = true;
        package = anixpkgs.flask-url2mp4;
        port = 4051;
    };

    networking.firewall.allowedTCPPorts = [
        4050
        4051
    ];
}
