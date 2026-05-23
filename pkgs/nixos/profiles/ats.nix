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

  config =
    (mkProfileConfig {
      machineType = "x86_linux";
      graphical = false;
      recreational = false;
      developer = true;
      isATS = true;
      claudeMarketplaces = claudeDefaults.marketplaces;
      claudePlugins = claudeDefaults.plugins;
      claudePermissionsAllow = claudeDefaults.permissionsAllow;
      claudeHooks = claudeDefaults.hooks;
      claudeSkills = claudeDefaults.skills;
      claudeMcpServers = [
        claudeDefaults.mcpServers.vikunja
        claudeDefaults.mcpServers.notion
        claudeDefaults.mcpServers.wiki
      ];
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
          name = "ats-triaging";
          jobShellScript = pkgs.writeShellScript "ats-triaging" ''
            authm refresh --headless || { >&2 logger -t authm "authm refresh error!"; exit 1; }
            rcrsync sync configs || { >&2 logger -t authm "configs sync error!"; exit 1; }
            goromail --wiki-user "$(cat $HOME/secrets/wiki/u.txt)" --wiki-pass "$(sread $HOME/secrets/wiki/p.txt.tyz)" --wiki-url http://${config.networking.hostName}.local --headless annotate-triage-pages ${anixpkgs.redirects.suppress_all}
            if [[ ! -z "$(cat $HOME/goromail/annotate.log)" ]]; then
              logger -t ats-triaging "Triaged notion pages"
            fi
          '';
          timerCfg = {
            OnCalendar = [ "*-*-* 00:00:00" ];
            Persistent = true;
          };
        }
        {
          name = "ats-mailman";
          execStartPre = pkgs.writeShellScript "ats-mailman-fix-perms" ''
            for f in /var/mail/goromail/new/*; do
              [ -e "$f" ] || exit 0
              chmod 660 "$f"
            done
          '';
          jobShellScript = pkgs.writeShellScript "ats-mailman" ''
            if [ -z "$( ls -A '/var/mail/goromail/new' )" ]; then
              exit
            fi
            DIAG_LOG="$HOME/goromail/mailman-diag.log"
            mkdir -p "$HOME/goromail"
            echo "[$(date '+%H:%M:%S')] START authm refresh" >> "$DIAG_LOG"
            authm refresh --headless >> "$DIAG_LOG" 2>&1 || { logger -t ats-mailman "authm refresh error!"; echo "[$(date '+%H:%M:%S')] FAILED authm refresh" >> "$DIAG_LOG"; exit 1; }
            echo "[$(date '+%H:%M:%S')] START rcrsync configs" >> "$DIAG_LOG"
            rcrsync sync configs >> "$DIAG_LOG" 2>&1 || { logger -t ats-mailman "configs sync error!"; echo "[$(date '+%H:%M:%S')] FAILED rcrsync configs" >> "$DIAG_LOG"; exit 1; }
            echo "[$(date '+%H:%M:%S')] START goromail postfix" >> "$DIAG_LOG"
            goromail --wiki-user "$(cat $HOME/secrets/wiki/u.txt)" --wiki-pass "$(sread $HOME/secrets/wiki/p.txt.tyz)" --wiki-url http://${config.networking.hostName}.local --headless postfix >> "$DIAG_LOG" 2>&1
            echo "[$(date '+%H:%M:%S')] END goromail postfix (exit $?)" >> "$DIAG_LOG"
            if [[ ! -z "$(cat $HOME/goromail/postfix.log)" ]]; then
              logger -t ats-mailman "Processed mail"
              if grep -qi "notion" $HOME/goromail/postfix.log; then
                echo "[$(date '+%H:%M:%S')] START goromail annotate-triage-pages" >> "$DIAG_LOG"
                goromail --wiki-user "$(cat $HOME/secrets/wiki/u.txt)" --wiki-pass "$(sread $HOME/secrets/wiki/p.txt.tyz)" --wiki-url http://${config.networking.hostName}.local --headless annotate-triage-pages >> "$DIAG_LOG" 2>&1
                echo "[$(date '+%H:%M:%S')] END goromail annotate-triage-pages (exit $?)" >> "$DIAG_LOG"
              fi
            fi
          '';
          timerCfg = {
            OnBootSec = "5m";
            OnUnitActiveSec = "60m";
          };
        }
        {
          name = "ats-workout-planner";
          jobShellScript = pkgs.writeShellScript "ats-workout-planner" ''
            authm refresh --headless || { logger -t authm "Authm refresh UNSUCCESSFUL"; >&2 echo "authm refresh error!"; exit 1; }
            rcrsync sync configs || { logger -t authm "Configs sync UNSUCCESSFUL"; >&2 echo "configs sync error!"; exit 1; }
            workout-planner --enable-logging generate
            logger -t ats-workout-planner "💪 Daily workout plan generated and published"
          '';
          timerCfg = {
            OnCalendar = [ "*-*-* 05:30:00" ];
            Persistent = true;
          };
        }
        {
          name = "ats-task-migrator";
          jobShellScript = pkgs.writeShellScript "ats-task-migrator" ''
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
          name = "ats-vikunja-backup";
          jobShellScript = pkgs.writeShellScript "ats-vikunja-backup" ''
            mkdir -p $HOME/data/vikunja
            cp /var/lib/vikunja/vikunja.db $HOME/data/vikunja/vikunja.db || { logger -t ats-vikunja-backup "DB copy UNSUCCESSFUL"; >&2 echo "backup error!"; exit 1; }
            rcrsync override data vikunja || { logger -t ats-vikunja-backup "Vikunja Backup UNSUCCESSFUL"; >&2 echo "backup error!"; exit 1; }
            logger -t ats-vikunja-backup "Backup successful!"
          '';
          timerCfg = {
            OnCalendar = [ "*-*-* 00:00:00" ];
            Persistent = false;
          };
        }
        {
          name = "ats-la-quiz-backup";
          jobShellScript = pkgs.writeShellScript "ats-la-quiz-backup" ''
            rcrsync override data la-quiz-web || { logger -t authm "LA Quiz Backup UNSUCCESSFUL"; >&2 echo "backup error!"; exit 1; }
            logger -t ats-la-quiz-backup "LA Quiz backup successful!"
          '';
          timerCfg = {
            OnCalendar = [ "*-*-* 00:00:00" ];
            Persistent = false;
          };
        }
        {
          name = "ats-tester-backup";
          jobShellScript = pkgs.writeShellScript "ats-tester-backup" ''
            rcrsync override data tester || { logger -t ats-tester-backup "Tester Backup UNSUCCESSFUL"; >&2 echo "backup error!"; exit 1; }
            logger -t ats-tester-backup "Tester backup successful!"
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
            OnCalendar = [ "*-*-* 00:30:00" ];
            Persistent = false;
          };
        }
        {
          name = "ats-survey-update";
          jobShellScript = pkgs.writeShellScript "ats-survey-update" ''
            authm refresh --headless || { >&2 logger -t authm "authm refresh error!"; exit 1; }
            rcrsync copy configs && surveys_report upload-results
          '';
          timerCfg = {
            OnCalendar = [
              "*-*-* 00:30:00"
              "*-*-* 18:30:00"
            ];
            Persistent = false;
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
          name = "ats-gmail-clean";
          jobShellScript = pkgs.writeShellScript "ats-gmail-clean" ''
            sleep 5
            authm refresh --headless || { >&2 logger -t authm "authm refresh error!"; exit 1; }
            sleep 5
            gmail-manager clean --num-messages 4000
            logger -t ats-gmail-clean "GMail cleaning complete"
          '';
          timerCfg = {
            OnCalendar = [ "Sat 23:00" ];
            Persistent = false;
          };
        }
      ];
      extraOrchestratorPackages = [
        anixpkgs.wiki-tools
        anixpkgs.task-tools
        anixpkgs.workout-planner
        anixpkgs.goromail
        anixpkgs.sread
        anixpkgs.gmail-parser
        anixpkgs.providence-tasker
        anixpkgs.daily_tactical_server
        anixpkgs.surveys_report
      ];
    })
    // {
      users.users.andrew.hashedPassword = lib.mkForce "$6$Kof8OUytwcMojJXx$vc82QBfFMxCJ96NuEYsrIJ0gJORjgpkeeyO9PzCBgSGqbQePK73sa13oK1FGY1CGd09qbAlsdiXWmO6m9c3K.0";
      users.users.andrew.extraGroups = [ "vikunja" ];
      environment.systemPackages = [
        (pkgs.writeShellScriptBin "anix-init" ''
          make-title -c yellow "Setting up rcrsync"

          DO_RCLONE=y
          if [[ -f $HOME/.config/rclone/rclone.conf ]]; then
            read -rp "rclone config already found, proceed anyway? (y|n): " DO_RCLONE
          fi
          if [[ "$DO_RCLONE" == "y" ]]; then
            read -rp "Enter the char key to unlock the rclone config: " CFGKEY
            rm -rf $HOME/.config/rclone
            mkdir -p $HOME/.config/rclone && cd $HOME/.config/rclone
            cp ${anixpkgs.pkgData.records.rcloneConf.data} ${anixpkgs.pkgData.records.rcloneConf.name}
            sunnyside -s 0 -k $CFGKEY -t ${anixpkgs.pkgData.records.rcloneConf.name}
            rm ${anixpkgs.pkgData.records.rcloneConf.name}
          else
            echo_yellow "Skipping rclone config step"
          fi

          cd $HOME
          rcrsync -v init configs
          rcrsync -v init secrets
          rcrsync -v init data

          make-title -c yellow "Setting up SSH and Nix"

          DO_SSH=y
          if [[ -d $HOME/.ssh ]]; then
            read -rp ".ssh directory already present, proceed anyway? (y|n): " DO_SSH
          fi
          if [[ "$DO_SSH" == "y" ]]; then
            rm -rf $HOME/.ssh
            cp -r $HOME/data/.ssh $HOME/.ssh
            cd $HOME/.ssh
            fix-perms .
            cd ..
          else
            echo_yellow "Skipping SSH config setup"
          fi

          sudo nix-channel --add https://nixos.org/channels/nixos-${nixos-version} nixpkgs
          sudo nix-channel --add https://nixos.org/channels/nixos-${nixos-version} nixos
          sudo nix-channel --add https://github.com/nix-community/home-manager/archive/release-${nixos-version}.tar.gz home-manager
          sudo nix-channel --update
          echo
          echo
          echo_green "DONE. Note the hardware-config.nix file below:"
          echo
          nixos-generate-config --show-hardware-config
          echo
          echo_green  "Use the config above as you set up anix-upgrade:"
          echo_yellow "  - Use devshell to create a workspace with anixpkgs"
          echo_yellow "  - Use the config above to define a new configuration in anixpkgs"
          echo_yellow "  - Symlink /etc/nixos/configuration.nix to $HOME/sources"
          echo_yellow "  - Run anix-upgrade"
          echo_yellow "  - Create new secrets and configs entries"
          echo
          echo_green "Have fun!"
        '')
      ];
    };
}
