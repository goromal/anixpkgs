{ config, pkgs, lib, ... }:
with import ../dependencies.nix; {
  imports = [ ../pc-base.nix ];

  config = mkProfileConfig {
    machineType = "x86_linux";
    graphical = true;
    recreational = true;
    developer = true;
    isATS = false;
    serveNotesWiki = false;
    isInstaller = false;
    enableMetrics = true;
    enableFileServers = false;
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
        name = "data";
        cloudname = "box:data";
        dirname = "data";
      }
      {
        name = "documents";
        cloudname = "drive:Documents";
        dirname = "Documents";
      }
      {
        name = "games";
        cloudname = "dropbox:games";
        dirname = "games";
      }
      {
        name = "games2";
        cloudname = "drive:MoreGames";
        dirname = "more-games";
      }
    ];
    enableOrchestrator = true;
    timedOrchJobs = [{
      name = "budgets-backup";
      jobShellScript = pkgs.writeShellScript "budgets-backup" ''
        rcrsync override data budgets || { logger -t budgets-backup "Budgets backup UNSUCCESSFUL"; >&2 echo "backup error!"; exit 1; }
        logger -t budgets-backup "Budgets backup successful 🎆"
      '';
      timerCfg = {
        OnBootSec = "5m";
        OnUnitActiveSec = "60m";
      };
    }];
    extraOrchestratorPackages = [ ];
  };
}
