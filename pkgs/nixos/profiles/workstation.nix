{
  config,
  pkgs,
  lib,
  ...
}:
with import ../dependencies.nix;
let
  claudeDefaults = import ../claude-defaults.nix;
in
{
  imports = [ ../pc-base.nix ];

  config = mkProfileConfig {
    machineType = "x86_linux";
    graphical = true;
    recreational = false;
    developer = true;
    isATS = false;
    claudeMarketplaces = claudeDefaults.marketplaces;
    claudePlugins = claudeDefaults.plugins;
    claudePermissionsAllow = claudeDefaults.permissionsAllow;
    claudeHooks = claudeDefaults.hooks;
    claudeSkills = claudeDefaults.skills;
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
}
