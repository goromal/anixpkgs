{ config, pkgs, lib, ... }: {
  imports = [ ../hardware/pi4.nix ../profiles/ats.nix ];
  machines.base.nixosState = "24.05";
  machines.base.machineType = pkgs.lib.mkForce "pi4";
  networking.hostName = "ats-pi";
}
