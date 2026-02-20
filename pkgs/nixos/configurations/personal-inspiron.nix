{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../profiles/personal.nix
    ../hardware/inspiron.nix
  ];
  machines.base.nixosState = "22.05";
  machines.base.wifiInterfaceName = "wlp1s0";
  machines.base.bootMntPt = "/boot/efi";
  networking.hostName = "atorgesen-inspiron";
}
