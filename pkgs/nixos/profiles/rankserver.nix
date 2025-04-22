{ config, pkgs, lib, ... }:
with import ../dependencies.nix;
let ports = import ../service-ports.nix;
in {
  imports =
    [ ../pc-base.nix ../../python-packages/flasks/rankserver/module.nix ];

  machines.base = {
    machineType = "pi4";
    graphical = false;
    recreational = false;
    developer = false;
    isATS = false;
    serveNotesWiki = false;
    isInstaller = false;
  };

  services.rankserver =
    { # TODO make this a pc-base option and adopt mkProfileConfig
      enable = true;
      package = anixpkgs.rankserver-cpp;
      dataDir = "rankables";
      port = ports.rankserver;
      openFirewall = true;
    };
}
