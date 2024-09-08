{ config, pkgs, lib, ... }:
with import ../dependencies.nix { inherit config; };
let ports = import ../service-ports.nix;
in {
  imports =
    [ ../pc-base.nix ../../python-packages/flasks/rankserver/module.nix ];

  machines.base = {
    machineType = "pi4";
    graphical = false;
    recreational = false;
    developer = false;
    loadATSServices = false;
    serveNotesWiki = false;
    isInstaller = false;
  };

  services.rankserver = {
    enable = true;
    package = anixpkgs.rankserver-cpp;
    dataDir = "rankables";
    port = ports.rankserver;
    openFirewall = true;
  };
}
