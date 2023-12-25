{ config, pkgs, lib, ... }: {
  imports = [ ../profiles/personal.nix ../hardware/inspiron.nix ];
  services.logind.lidSwitchExternalPower = "ignore";
  networking.hostName = "atorgesen-inspiron";
}
