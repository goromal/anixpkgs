{ config, pkgs, lib, ... }:
with pkgs;
with lib;
{
    imports = [
        ../base.nix
        ../../ros-packages/ros-core-modules/roscore-module.nix
    ];

    nix.nixPath = mkForce [
        "nixpkgs=${cleanSource ../../..}"
    ];

    networking.hostName = "multirotorFcm";
    services.xserver.enable = true;
    services.xserver.displayManager = {
        lightdm.enable = true;
        defaultSession = lib.mkDefault "none+icewm";
        autoLogin = {
            enable = true;
            user = "andrew";
        };
    };
    services.xserver.windowManager.icewm.enable = true;

    environment.systemPackages = [
        rosPackages.noetic.rosnode
        rosPackages.noetic.rostopic
        rosPackages.noetic.roslaunch
    ];

    services.roscore = {
        enable = true;
    };
}
