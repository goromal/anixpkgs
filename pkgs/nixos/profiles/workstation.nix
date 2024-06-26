{ config, pkgs, lib, ... }: {
  imports = [ ../base.nix ];

  machines.base = {
    machineType = "x86_linux";
    graphical = true;
    recreational = false;
    developer = true;
    loadATSServices = false;
    serveNotesWiki = false;
    isInstaller = false;
  };
}
