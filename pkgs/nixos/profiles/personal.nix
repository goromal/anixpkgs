{
  config,
  pkgs,
  lib,
  ...
}:
let
  claudeDefaults = import ../claude-defaults.nix;
in
{
  imports = [ ../pc-base.nix ];

  config = {
    machines.base = {
      machineType = "x86_linux";
      graphical = true;
      recreational = true;
      developer = true;
      isATS = false;
      agentFramework = "claude";
      serveNotesWiki = false;
      enableMetrics = true;
      enableFileServers = true;
      enableUpgradeUI = true;
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
      timedOrchJobs = [
        {
          name = "budgets-backup";
          jobShellScript = pkgs.writeShellScript "budgets-backup" ''
            rcrsync override data budgets || { logger -t budgets-backup "Budgets backup UNSUCCESSFUL"; >&2 echo "backup error!"; exit 1; }
            logger -t budgets-backup "Budgets backup successful 🎆"
          '';
          timerCfg = {
            OnBootSec = "5m";
            OnUnitActiveSec = "60m";
          };
        }
      ];
      extraOrchestratorPackages = [ ];
    };
    machines.claude = {
      marketplaces = claudeDefaults.marketplaces;
      plugins = claudeDefaults.plugins;
      permissionsAllow = claudeDefaults.permissionsAllow;
      hooks = claudeDefaults.hooks;
      skills = claudeDefaults.skills;
      mcpServers = [
        claudeDefaults.mcpServers.notion
        claudeDefaults.mcpServers.wiki
      ];
    };
    services.logind.settings.Login.HandleLidSwitch = "ignore";
  };
}
