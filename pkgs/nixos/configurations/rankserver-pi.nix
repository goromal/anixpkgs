{ config, pkgs, lib, ... }: {
  imports = [ ../hardware/pi4.nix ../profiles/rankserver.nix ];
  networking.hostName = "rankserver-pi4";
  nix.nixPath = [
    "nixos-config=/data/andrew/sources/anixpkgs/pkgs/nixos/configurations/rankserver-pi.nix"
  ];
}
