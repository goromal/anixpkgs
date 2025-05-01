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
    enableOrchestrator = true;
    timedOrchJobs = [{
      name = "budgets-backup";
      jobShellScript = pkgs.writeShellScript "budgets-backup" ''
        rcrsync override data budgets || { logger -t budgets-backup "Budgets backup UNSUCCESSFUL"; >&2 echo "backup error!"; exit 1; }
        logger -t budgets-backup "Budgets backup successful!"
      '';
      timerCfg = {
        OnBootSec = "5m";
        OnUnitActiveSec = "60m";
      };
    }];
    extraOrchestratorPackages = [ ];
  };
}
