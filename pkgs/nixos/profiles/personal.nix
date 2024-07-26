{ config, pkgs, lib, ... }: {
  imports = [ ../base.nix ];

  machines.base = {
    machineType = "x86_linux";
    graphical = true;
    recreational = true;
    developer = true;
    loadATSServices = true;
    serveNotesWiki = false;
    isInstaller = false;
  };
}
