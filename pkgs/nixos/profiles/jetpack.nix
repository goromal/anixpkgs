{
  config,
  pkgs,
  lib,
  ...
}:
with import ../dependencies.nix;
let
  claudeDefaults = import ../claude-defaults.nix;
  codexDefaults = import ../codex-defaults.nix { homeDir = config.machines.base.homeDir; };
in
{
  imports = [ ../pc-base.nix ];

  config = {
    machines.base = {
      machineType = "jetson";
      graphical = false;
      recreational = false;
      developer = true;
      isATS = false;
      agentFrameworks = [
        "claude"
        "codex"
      ];
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
      ];
      enableOrchestrator = true;
      timedOrchJobs = [
        {
          name = "launchpad-sync";
          jobShellScript = pkgs.writeShellScript "launchpad-sync" ''
            export PATH="${
              pkgs.lib.makeBinPath [
                pkgs.git
                pkgs.openssh
              ]
            }:$PATH"
            REPO=$HOME/launchpad
            if [[ -d "$REPO/.git" ]]; then
              cd "$REPO"
              if [[ -n "$(git status --porcelain)" ]]; then
                git add -A
                git commit -m "Auto-commit $(date '+%Y-%m-%d %H:%M:%S')"
              fi
              pull_out=$(git pull --rebase origin master 2>&1)
              if [[ $? -eq 0 ]]; then
                push_out=$(git push origin master 2>&1)
                if [[ $? -eq 0 ]]; then
                  logger -t launchpad-sync "Sync complete"
                else
                  echo "$push_out" >&2
                  logger -t launchpad-sync "Push to master failed"
                fi
              else
                echo "$pull_out" >&2
                git rebase --abort 2>/dev/null
                logger -t launchpad-sync "Rebase conflict detected, manual intervention needed"
              fi
            else
              logger -t launchpad-sync "No git repository found at $REPO, skipping"
            fi
          '';
          timerCfg = {
            OnCalendar = [ "*-*-* 03:00:00" ];
            Persistent = true;
          };
        }
      ];
      extraOrchestratorPackages = [
        anixpkgs.wiki-tools
        anixpkgs.task-tools
        anixpkgs.notion-tools
        anixpkgs.goromail
        anixpkgs.sread
        anixpkgs.gmail-parser
        anixpkgs.providence-tasker
        anixpkgs.daily_tactical_server
        anixpkgs.surveys_report
      ];
    };
    machines.cudaNode.enable = true;
    machines.claude = {
      marketplaces = claudeDefaults.marketplaces;
      plugins = claudeDefaults.plugins;
      permissionsAllow = claudeDefaults.permissionsAllow;
      hooks = claudeDefaults.hooks;
      skills = claudeDefaults.skills;
      mcpServers = [
        claudeDefaults.mcpServers.vikunja
        claudeDefaults.mcpServers.notion
        claudeDefaults.mcpServers.jupyter
        claudeDefaults.mcpServers.googleSheets
      ];
    };
    machines.codex = {
      model = codexDefaults.model;
      modelProvider = codexDefaults.modelProvider;
      approvalPolicy = codexDefaults.approvalPolicy;
      sandboxMode = codexDefaults.sandboxMode;
      extraSettings = codexDefaults.extraSettings;
      skills = codexDefaults.skills;
      mcpServers = [
        codexDefaults.mcpServers.vikunja
        codexDefaults.mcpServers.notion
        codexDefaults.mcpServers.jupyter
        codexDefaults.mcpServers.googleSheets
      ];
    };
    users.users.andrew.hashedPassword = lib.mkForce "$6$Kof8OUytwcMojJXx$vc82QBfFMxCJ96NuEYsrIJ0gJORjgpkeeyO9PzCBgSGqbQePK73sa13oK1FGY1CGd09qbAlsdiXWmO6m9c3K.0";
    services.google-sheets-mcp.enable = true;
    environment.systemPackages = [
      anixpkgs.jetson-stats
    ];
  };
}
