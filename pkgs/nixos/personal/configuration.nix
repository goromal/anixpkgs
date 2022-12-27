{ config, pkgs, lib, ... }:
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

    # Essential Firmware
    hardware.enableRedistributableFirmware = lib.mkDefault true;

    # # Inspiron Touchpad (move to hardware-configuration?)
    # boot.kernelModules = [ "psmouse" ];
    # boot.kernelParams = [ "psmouse.synaptics_intertouch=0" ]; # https://wiki.ubuntu.com/DebuggingTouchpadDetection
    # services.xserver = {
    #     libinput.enable = true;
    #     libinput.touchpad.tapping = true;
    #     libinput.touchpad.tappingDragLock = true;
    #     exportConfiguration = true;
    # };
}
