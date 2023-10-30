{ config, pkgs, lib, ... }: {
  imports = [ ../hardware/inspiron.nix ../profiles/personal.nix ];
  networking.hostName = "atorgesen-inspiron";
}
