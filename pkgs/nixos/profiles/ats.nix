{ config, pkgs, lib, ... }: {
  imports = [ ../base.nix ];

  machines.base = {
    # machineType to be filled out in the end configuration
    graphical = false;
    recreational = false;
    developer = false;
    loadATSServices = true;
    isInstaller = false;
  };
}
