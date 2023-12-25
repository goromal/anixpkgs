{ config, pkgs, lib, ... }: {
  imports = [ ../base.nix ];

  services.logind.lidSwitchExternalPower = "ignore";

  machines.base = {
    machineType = "x86_linux";
    graphical = true;
    recreational = true;
    isServer = true; # ^^^^ TODO false
  };
}
