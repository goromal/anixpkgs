{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../profiles/personal.nix
    ../hardware/dell.nix
  ];
  machines.base.nixosState = "25.11";
  # machines.base.wifiInterfaceName = "wlo1"; TODO - test with adapter
  machines.base.acceptRemoteBuilds = true;
  machines.cudaNode.enable = true;
  networking.hostName = "atorgesen-dell";
}
