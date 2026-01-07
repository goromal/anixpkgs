{ config, pkgs, lib, ... }: {
  imports = [ ../profiles/personal.nix ../hardware/inspiron.nix ];
  machines.base.nixosState = "22.05";
  machines.base.wifiInterfaceName = "TODO"; # ^^^^
  machines.base.bootMntPt = "/boot/efi";
  networking.hostName = "atorgesen-inspiron";
}
