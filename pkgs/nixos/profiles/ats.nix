{ config, pkgs, lib, ... }:
with import ../dependencies.nix; {
  imports = [ ../pc-base.nix ];

  config = (mkProfileConfig {
    machineType = "x86_linux";
    graphical = false;
    recreational = false;
    developer = false;
    isATS = true;
    serveNotesWiki = true;
    notesWikiPort = 8080;
    enableMetrics = true;
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
        name = "games";
        cloudname = "dropbox:games";
        dirname = "games";
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
    ];
    enableOrchestrator = true;
    timedOrchJobs = [
      {
        name = "ats-greeting";
        jobShellScript = pkgs.writeShellScript "ats-greeting" ''
          sleep 5
          authm refresh --headless || { >&2 logger -t authm "authm refresh error!"; exit 1; }
          sleep 5
          gmail-manager gbot-send 6612105214@vzwpix.com "ats-greeting" \
            "[$(date)] 🌞 Hello, world! I'm awake! authm refreshed successfully ✅"
          gmail-manager gbot-send andrew.torgesen@gmail.com "ats-greeting" \
            "[$(date)] 🌞 Hello, world! I'm awake! authm refreshed successfully ✅"
        '';
        timerCfg = {
          OnBootSec = "1m";
          Persistent = false;
        };
      }
      {
        name = "ats-triaging";
        jobShellScript = pkgs.writeShellScript "ats-triaging" ''
          authm refresh --headless || { >&2 logger -t authm "authm refresh error!"; exit 1; }
          rcrsync sync configs || { >&2 logger -t authm "configs sync error!"; exit 1; }
          goromail --wiki-user "$(cat $HOME/secrets/wiki/u.txt)" --wiki-pass "$(sread $HOME/secrets/wiki/p.txt.tyz)" --wiki-url http://${config.networking.hostName}.local --headless annotate-triage-pages ${anixpkgs.redirects.suppress_all}
          if [[ ! -z "$(cat $HOME/goromail/annotate.log)" ]]; then
            echo "Notifying about processed triage pages..."
            echo "[$(date)] 🧮 Triage Calculations:" \
              | cat - $HOME/goromail/annotate.log > $HOME/goromail/temp2 \
              && mv $HOME/goromail/temp2 $HOME/goromail/annotate.log
            logger -t ats-triaging "$(cat $HOME/goromail/annotate.log)"
          fi
        '';
        timerCfg = {
          OnCalendar = [ "*-*-* 06:30:00" "*-*-* 18:30:00" ];
          Persistent = true;
        };
      }
      {
        name = "ats-mailman";
        jobShellScript = pkgs.writeShellScript "ats-mailman" ''
          authm refresh --headless || { >&2 logger -t authm "authm refresh error!"; exit 1; }
          rcrsync sync configs || { >&2 logger -t authm "configs sync error!"; exit 1; }
          goromail --wiki-user "$(cat $HOME/secrets/wiki/u.txt)" --wiki-pass "$(sread $HOME/secrets/wiki/p.txt.tyz)" --wiki-url http://${config.networking.hostName}.local --headless bot ${anixpkgs.redirects.suppress_all}
          goromail --wiki-user "$(cat $HOME/secrets/wiki/u.txt)" --wiki-pass "$(sread $HOME/secrets/wiki/p.txt.tyz)" --wiki-url http://${config.networking.hostName}.local --headless journal ${anixpkgs.redirects.suppress_all}
          if [[ ! -z "$(cat $HOME/goromail/bot.log)" ]]; then
            echo "Notifying about processed bot mail..."
            echo "[$(date)] 📬 Bot mail received:" \
              | cat - $HOME/goromail/bot.log > $HOME/goromail/temp \
              && mv $HOME/goromail/temp $HOME/goromail/bot.log
            logger -t ats-mailman "$(cat $HOME/goromail/bot.log)"
          fi
          if [[ ! -z "$(cat $HOME/goromail/journal.log)" ]]; then
            echo "Notifying about processed journal mail..."
            echo "[$(date)] 📖 Journal mail received:" \
              | cat - $HOME/goromail/journal.log > $HOME/goromail/temp \
              && mv $HOME/goromail/temp $HOME/goromail/journal.log
            logger -t ats-mailman "$(cat $HOME/goromail/journal.log)"
          fi
        '';
        timerCfg = {
          OnBootSec = "5m";
          OnUnitActiveSec = "10m";
        };
      }
      {
        name = "ats-grader";
        jobShellScript = pkgs.writeShellScript "ats-grader" ''
          authm refresh --headless || { logger -t authm "Authm refresh UNSUCCESSFUL"; >&2 echo "authm refresh error!"; exit 1; }
          tmpdir=$(mktemp -d)
          echo "🧹 Daily Task Cleaning 🧹" > $tmpdir/out.txt
          echo "" >> $tmpdir/out.txt
          current_year=$(date +"%Y")
          task-tools clean --start-date "''${current_year}-01-01" >> $tmpdir/out.txt
          logger -t ats-grader "$(cat $tmpdir/out.txt)"
          rm -r $tmpdir
        '';
        timerCfg = {
          OnCalendar = [ "*-*-* 06:00:00" ];
          Persistent = true;
        };
      }
      {
        name = "ats-prov-tasker";
        jobShellScript = pkgs.writeShellScript "ats-prov-tasker" ''
          authm refresh --headless || { logger -t authm "Authm refresh UNSUCCESSFUL"; >&2 echo "authm refresh error!"; exit 1; }
          providence-tasker --wiki-url http://${config.networking.hostName}.local 7 ${anixpkgs.redirects.suppress_all}
          logger -t ats-prov-tasker "📖 Happy Sunday! Providence-tasker has deployed for the coming week ✅"
        '';
        timerCfg = {
          OnCalendar = [ "Sun *-*-* 08:00:00" ];
          Persistent = false;
        };
      }
      {
        name = "ats-wiki-backup";
        jobShellScript = pkgs.writeShellScript "ats-wiki-backup" ''
          rcrsync override data notes-wiki || { logger -t authm "Backup UNSUCCESSFUL"; >&2 echo "backup error!"; exit 1; }
          logger -t ats-wiki-backup "Backup successful!"
        '';
        timerCfg = {
          OnCalendar = [ "*-*-* 00:00:00" ];
          Persistent = false;
        };
      }
      {
        name = "ats-tactical-backup";
        jobShellScript = pkgs.writeShellScript "ats-tactical-backup" ''
          rcrsync override data tacticald || { logger -t authm "Tacticald Backup UNSUCCESSFUL"; >&2 echo "backup error!"; exit 1; }
          logger -t ats-tactical-backup "Backup successful!"
        '';
        timerCfg = {
          OnCalendar = [ "*-*-* 00:00:00" ];
          Persistent = false;
        };
      }
      {
        name = "ats-tactical-dailies";
        jobShellScript = pkgs.writeShellScript "ats-tactical-dailies" ''
          authm refresh --headless || { >&2 logger -t authm "authm refresh error!"; exit 1; }
          tactical --wiki-user "$(cat $HOME/secrets/wiki/u.txt)" --wiki-pass "$(sread $HOME/secrets/wiki/p.txt.tyz)" --wiki-url http://${config.networking.hostName}.local journal
          tactical --wiki-user "$(cat $HOME/secrets/wiki/u.txt)" --wiki-pass "$(sread $HOME/secrets/wiki/p.txt.tyz)" --wiki-url http://${config.networking.hostName}.local quote
          tactical --wiki-user "$(cat $HOME/secrets/wiki/u.txt)" --wiki-pass "$(sread $HOME/secrets/wiki/p.txt.tyz)" --wiki-url http://${config.networking.hostName}.local vocab
          tactical --wiki-user "$(cat $HOME/secrets/wiki/u.txt)" --wiki-pass "$(sread $HOME/secrets/wiki/p.txt.tyz)" --wiki-url http://${config.networking.hostName}.local wiki-url
        '';
        timerCfg = {
          OnCalendar = [ "*-*-* 00:00:00" ];
          Persistent = false;
        };
      }
      {
        name = "ats-tactical-intervaled";
        jobShellScript = pkgs.writeShellScript "ats-tactical-intervaled" ''
          authm refresh --headless || { >&2 logger -t authm "authm refresh error!"; exit 1; }
          tactical --wiki-user "$(cat $HOME/secrets/wiki/u.txt)" --wiki-pass "$(sread $HOME/secrets/wiki/p.txt.tyz)" --wiki-url http://${config.networking.hostName}.local tasks
        '';
        timerCfg = {
          OnBootSec = "5m";
          OnUnitActiveSec = "10m";
        };
      }
      {
        name = "ats-itns-nudge";
        jobShellScript = pkgs.writeShellScript "ats-itns-nudge" ''
          authm refresh --headless || { >&2 logger -t authm "authm refresh error!"; exit 1; }
          rcrsync sync configs || { >&2 logger -t authm "configs sync error!"; exit 1; }
          output=$(goromail itns-nudge)
          logger -t ats-itns-nudge "$output"
        '';
        timerCfg = {
          OnCalendar = [ "Mon 12:00" ];
          Persistent = false;
        };
      }
      {
        name = "ats-refresh-reminder";
        jobShellScript = pkgs.writeShellScript "ats-refresh-reminder" ''
          authm refresh --headless || { >&2 logger -t authm "authm refresh error!"; exit 1; }
          rcrsync copy configs || { >&2 logger -t authm "configs sync error!"; exit 1; }
          gmail-manager gbot-send 6612105214@vzwpix.com "Gentle Reminder" \
            "[$(date)] 👋 When you have a second, please refresh my credentials at http://$(cat ~/secrets/ats/i.txt)/auth/"
          gmail-manager gbot-send andrew.torgesen@gmail.com "Gentle Reminder" \
            "[$(date)] 👋 When you have a second, please refresh my credentials at http://$(cat ~/secrets/ats/i.txt)/auth/"
        '';
        timerCfg = {
          OnCalendar = [ "Sun 19:00" ];
          Persistent = false;
        };
      }
    ];
    extraOrchestratorPackages = [
      anixpkgs.wiki-tools
      anixpkgs.task-tools
      anixpkgs.mp4
      anixpkgs.mp4unite
      anixpkgs.goromail
      anixpkgs.sread
      anixpkgs.gmail-parser
      anixpkgs.scrape
      anixpkgs.providence-tasker
      anixpkgs.daily_tactical_server
    ];
  }) // {
    users.users.andrew.hashedPassword = lib.mkForce
      "$6$Kof8OUytwcMojJXx$vc82QBfFMxCJ96NuEYsrIJ0gJORjgpkeeyO9PzCBgSGqbQePK73sa13oK1FGY1CGd09qbAlsdiXWmO6m9c3K.0";
  };
}
