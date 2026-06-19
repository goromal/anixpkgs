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
      recreational = false;
      developer = true;
      isATS = false;
      agentFramework = "claude";
      serveNotesWiki = false;
      enableMetrics = false;
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
          name = "documents";
          cloudname = "drive:Documents";
          dirname = "Documents";
        }
      ];
      enableOrchestrator = false;
      timedOrchJobs = [ ];
      extraOrchestratorPackages = [ ];
    };
    machines.claude = {
      marketplaces = claudeDefaults.marketplaces;
      plugins = claudeDefaults.plugins;
      permissionsAllow = claudeDefaults.permissionsAllow;
      hooks = claudeDefaults.hooks;
      skills = claudeDefaults.skills;
    };
  };
}
