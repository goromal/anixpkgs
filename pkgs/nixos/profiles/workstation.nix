{ config, pkgs, lib, ... }:
with import ../dependencies.nix; {
  imports = [ ../pc-base.nix ];

  config = mkProfileConfig {
    machineType = "x86_linux";
    graphical = true;
    recreational = false;
    developer = true;
    isATS = false;
    serveNotesWiki = false;
    isInstaller = false;
    enableMetrics = false;
    enableOrchestrator = false;
    timedOrchJobs = [ ];
    extraOrchestratorPackages = [ ];
  };
}
