{ config, pkgs, lib, ... }: {
  imports = [ ../base.nix ];

  machines.base = {
    machineType = "x86_linux";
    graphical = false;
    recreational = false;
    developer = false;
    loadATSServices = true;
    serveNotesWiki = true;
    isInstaller = false;
  };
}
