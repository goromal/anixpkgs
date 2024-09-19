{ config, pkgs, lib, ... }: {
  imports = [ ../profiles/drone.nix ];
  drone.base.nixosState = "24.05";
  drone.base.machine = "sitl";
  networking.hostName = "drone-sitl";
}