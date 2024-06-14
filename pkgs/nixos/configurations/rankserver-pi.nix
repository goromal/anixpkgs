{ config, pkgs, lib, ... }: {
  imports = [ ../hardware/pi4.nix ../profiles/rankserver.nix ];
  machines.base.nixosState = "24.05";
  networking.hostName = "rankserver-pi4";
}
