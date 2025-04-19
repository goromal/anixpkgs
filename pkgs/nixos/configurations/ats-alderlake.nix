{ config, pkgs, lib, ... }: {
  imports = [ ../hardware/alderlake.nix ../profiles/ats.nix ];
  machines.base.nixosState = "24.05";
  machines.base.bootMntPt = "/boot";
  networking.hostName = "ats";
  users.users.andrew.hashedPassword = lib.mkForce
    "$6$Kof8OUytwcMojJXx$vc82QBfFMxCJ96NuEYsrIJ0gJORjgpkeeyO9PzCBgSGqbQePK73sa13oK1FGY1CGd09qbAlsdiXWmO6m9c3K.0";
}
