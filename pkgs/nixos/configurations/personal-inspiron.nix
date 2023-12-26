{ config, pkgs, lib, ... }: {
  imports = [ ../profiles/personal.nix ../hardware/inspiron.nix ];
  networking.hostName = "atorgesen-inspiron";
}
