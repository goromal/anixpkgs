{ config, pkgs, lib, ... }: {
  imports = [ ../profiles/rankserver.nix ../hardware/pi4.nix ];
  networking.hostName = "rankserver-pi4";
}
