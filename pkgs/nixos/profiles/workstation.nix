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
    cloudDirs = [
      {
        name = "configs";
        cloudname = "dropbox:configs";
        dirname = "configs";
      }
      {
        name = "secrets";
        cloudname = "dropbox:secrets";
        dirname = "secrets";
      }
      {
        name = "documents";
        cloudname = "drive:Documents";
        dirname = "Documents";
      }
    ];
    enableOrchestrator = false;
    timedOrchJobs = [ ];
    extraOrchestratorPackages = [ ];
  };
}
