{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../profiles/jetpack.nix
    ../hardware/orin-agx.nix
  ];
  machines.base.nixosState = "25.11";
  machines.base.wifiInterfaceName = "wlP1p1s0";
  hardware.nvidia-jetpack.som = "orin-agx";
  hardware.nvidia-jetpack.carrierBoard = "devkit";
  networking.hostName = "jetson-orin-agx";

  services.comfyui.cozy.workflows = [
    "imggen"
    "imggen2"
  ];

  nix.settings.max-jobs = lib.mkForce 1;
  nix.settings.cores = lib.mkForce 4;

  machines.base.remoteBuilders = [
    "personal-inspiron"
    "personal-panasonic"
    "personal-dell"
  ];
}
