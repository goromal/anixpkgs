{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../profiles/jetpack.nix
    ../hardware/orin-nx.nix
  ];
  machines.base.nixosState = "26.05";
  machines.base.wifiInterfaceName = "wlp1s0";
  hardware.nvidia-jetpack.enable = true;
  hardware.nvidia-jetpack.som = "orin-nx";
  hardware.nvidia-jetpack.carrierBoard = "devkit";
  hardware.nvidia-jetpack.configureCuda = true;
  hardware.graphics.enable = true;
  networking.hostName = "jetson-orin-nx";

  nix.settings.max-jobs = lib.mkForce 1;
  nix.settings.cores = lib.mkForce 4;

  machines.base.remoteBuilders = [
    "personal-inspiron"
    "personal-panasonic"
    "personal-dell"
  ];
}
