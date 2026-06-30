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

  config = {
    machines.base = {
      machineType = "jetson";
      graphical = false;
      recreational = false;
      developer = true;
      isATS = false;
      agentFramework = "claude";
      serveNotesWiki = false;
      enableMetrics = false; # TODO: perhaps enable in the future
      enableFileServers = true;
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
    hardware.nvidia-jetpack.enable = true;
    hardware.nvidia-jetpack.configureCuda = true;
    hardware.graphics.enable = true;
    machines.cudaNode.enable = true;
    machines.claude = {
      marketplaces = claudeDefaults.marketplaces;
      plugins = claudeDefaults.plugins;
      permissionsAllow = claudeDefaults.permissionsAllow;
      hooks = claudeDefaults.hooks;
      skills = claudeDefaults.skills;
      mcpServers = [
        claudeDefaults.mcpServers.vikunja
        claudeDefaults.mcpServers.jupyter
      ];
    };
    users.users.andrew.hashedPassword = lib.mkForce "$6$Kof8OUytwcMojJXx$vc82QBfFMxCJ96NuEYsrIJ0gJORjgpkeeyO9PzCBgSGqbQePK73sa13oK1FGY1CGd09qbAlsdiXWmO6m9c3K.0";
    environment.systemPackages = [
      anixpkgs.jetson-stats
    ];
  };
}
