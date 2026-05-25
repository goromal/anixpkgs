{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../profiles/personal.nix
    ../hardware/panasonic.nix
  ];
  machines.base.nixosState = "25.05";
  machines.base.wifiInterfaceName = "wlo1";
  machines.base.acceptRemoteBuilds = true;
  networking.hostName = "atorgesen-panasonic";
}
