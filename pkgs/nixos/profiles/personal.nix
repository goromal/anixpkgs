{ config, pkgs, lib, ... }: {
  imports = [ ../pc-base.nix ];

  machines.base = {
    machineType = "x86_linux";
    graphical = true;
    recreational = true;
    developer = true;
    isATS = false;
    serveNotesWiki = false;
    isInstaller = false;
    enableMetrics = true;
  };
}
