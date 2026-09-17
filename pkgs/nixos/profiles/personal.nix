{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [ ../pc-base.nix ];

  config = {
    machines.base = {
      machineType = "x86_linux";
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
    };
    machines.features = {
      desktop.enable = true;
      development.enable = true;
      recreation.enable = true;
      headsetAudio.enable = true;
      externalDrives.enable = true;
      homeVpn.enable = true;
      agentUi.enable = true;
      upgradeUi.enable = true;
      fileServers.enable = true;
      metrics.enable = true;
      notesWiki.enable = false;
      orchestrator.enable = true;
      auth.enable = false;
      budget.enable = false;
      languageQuiz.enable = false;
      music.enable = false;
      tester.enable = false;
      disciple.enable = false;
      tasks.enable = false;
      videoDownload.enable = false;
      brom.enable = false;
      intake.enable = false;
      mail.enable = false;
      plex.enable = false;
      vikunja.enable = false;
      gameStreaming.enable = true;
      gpu.enable = false;
      notebooks.enable = false;
      imageGeneration.enable = false;
      localLlm.enable = false;
      folio.enable = true;
      tactical.enable = false;
      agents.frameworks = [
        "claude"
        "codex"
      ];
      orchestrator.jobs = [
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
        {
          name = "folio-backup";
          jobShellScript = pkgs.writeShellScript "folio-backup" ''
            DEST="$HOME/data/folio/${config.networking.hostName}"
            mkdir -p "$DEST"
            ${pkgs.sqlite}/bin/sqlite3 /var/lib/folio/folio.db ".backup '$DEST/folio.db'" \
              || { logger -t folio-backup "DB backup UNSUCCESSFUL"; >&2 echo "backup error!"; exit 1; }
            rcrsync override data folio \
              || { logger -t folio-backup "folio backup UNSUCCESSFUL"; >&2 echo "backup error!"; exit 1; }
            logger -t folio-backup "Backup successful!"
          '';
          timerCfg = {
            OnCalendar = [ "*-*-* 00:00:00" ];
            Persistent = false;
          };
        }
      ];
      orchestrator.extraPackages = [ ];
    };
    services.logind.settings.Login.HandleLidSwitch = "ignore";
  };
}
