{ config, pkgs, lib, ... }: {
  imports = [ ../profiles/personal.nix ../hardware/inspiron.nix ];
  machines.base.nixosState = "22.05";
  networking.hostName = "atorgesen-inspiron";
}
