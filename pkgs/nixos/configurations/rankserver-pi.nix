{ config, pkgs, lib, ... }: {
  imports = [ ../hardware/pi4.nix ../profiles/rankserver.nix ];
  networking.hostName = "rankserver-pi4";
}
