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
  machines.base.nixosState = "25.11";
  machines.base.wifiInterfaceName = "wlp1s0";
  hardware.nvidia-jetpack.som = "orin-nx";
  hardware.nvidia-jetpack.carrierBoard = "devkit";
  networking.hostName = "jetson-orin-nx";

  # Prevent OOM during large builds (e.g. PyTorch): one job at a time, all
  # cores available to it, with swap headroom for peak allocation spikes.
  swapDevices = [
    {
      device = "/swapfile";
      size = 8192;
    }
  ];
  nix.settings.max-jobs = lib.mkForce 1;
  nix.settings.cores = lib.mkForce 4;

  machines.base.remoteBuilders = [ "personal-inspiron" ];
}
