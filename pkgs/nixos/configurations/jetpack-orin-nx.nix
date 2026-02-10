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
  machines.base.nixosState = 25.11;
  machines.base.wifiInterfaceName = "wlp1s0";
  hardware.nvidia-jetpack.som = "orin-nx";
  hardware.nvidia-jetpack.carrierBoard = "devkit";
  networking.hostName = "jetson-orin-nx";
}
