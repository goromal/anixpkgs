{ config, pkgs, lib, ... }: {
  imports = [
    ../hardware/inspiron.nix
    ../profiles/personal.nix
  ];
  networking.hostName = "atorgesen-inspiron";
  nix.nixPath = [
    "nixos-config=/data/andrew/sources/anixpkgs/pkgs/nixos/configurations/personal-inspiron.nix"
  ];
}
