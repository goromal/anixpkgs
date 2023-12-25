{ config, pkgs, lib, ... }: {
  imports = [ ../profiles/personal.nix ../hardware/inspiron.nix ];
  # services.logind.lidSwitchExternalPower = "ignore"; TODO might not work
  networking.hostName = "atorgesen-inspiron";
}
