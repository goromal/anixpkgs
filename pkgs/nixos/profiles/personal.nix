{ config, pkgs, lib, ... }: {
  imports = [ ../pc-base.nix ];

  machines.base = {
    machineType = "x86_linux";
    graphical = true;
    recreational = true;
    developer = true;
    loadATSServices = false;
    serveNotesWiki = false;
    isInstaller = false;
    exportMetrics = true;
  };
}
