{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../hardware/alderlake.nix
    ../profiles/ats.nix
  ];
  machines.base.nixosState = "24.05";
  networking.hostName = "ats";
}
