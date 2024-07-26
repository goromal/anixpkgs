{ pkgs, config, lib, ... }:
with pkgs;
with lib;
with import ../../nixos/dependencies.nix { inherit config; };
let
  globalCfg = config.machines.base;
  cfg = config.services.ats;
  wiki-url = if globalCfg.serveNotesWiki then
    "http://localhost:80"
  else
    "https://notes.andrewtorgesen.com";
  oPathPkgs = with anixpkgs;
    let
      ats-rcrsync = rcrsync.override { cloudDirs = globalCfg.cloudDirs; };
      ats-authm = authm.override { rcrsync = ats-rcrsync; };
    in [
      bash
      coreutils
      rclone
      wiki-tools
      task-tools
      ats-rcrsync
      mp4
      mp4unite
      goromail
      gmail-parser
      scrape
      ats-authm
      providence-tasker
    ];
  mkOneshotTimedOrchService =
    { name, jobShellScript, timerCfg, readWritePaths ? [ "/" ] }: {
      systemd.timers."${name}" = {
        description = "${name} trigger timer";
        wantedBy = [ "timers.target" ];
        timerConfig = timerCfg // { Unit = "${name}.service"; };
      };
      systemd.services."${name}" = {
        enable = true;
        description = "${name} oneshot service";
        serviceConfig = {
          Type = "oneshot";
          ExecStart =
            "${anixpkgs.orchestrator}/bin/orchestrator bash 'bash ${jobShellScript}'";
          ReadWritePaths = readWritePaths;
        };
      };
    };
  atsServices = [
    {
      services.orchestratord = {
        enable = true;
        orchestratorPkg = anixpkgs.orchestrator;
        pathPkgs = oPathPkgs;
      };
    }
    (mkOneshotTimedOrchService {
      name = "ats-greeting";
      jobShellScript = writeShellScript "ats-greeting" ''
          sleep 5
        authm refresh --headless || { >&2 echo "authm refresh error!"; exit 1; }
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
    })
    (mkOneshotTimedOrchService {
      name = "ats-mailman";
      jobShellScript = writeShellScript "ats-mailman" ''
        authm refresh --headless || { >&2 echo "authm refresh error!"; exit 1; }
        rcrsync sync configs || { >&2 echo "configs sync error!"; exit 1; }
        # TODO warn about expiration
        goromail --wiki-url ${wiki-url} --headless bot --categories-csv ~/configs/new.goromail-pages.csv ${anixpkgs.redirects.suppress_all}
        goromail --wiki-url ${wiki-url} --headless journal ${anixpkgs.redirects.suppress_all}
        if [[ ! -z "$(cat $HOME/goromail/bot.log)" ]]; then
          echo "Notifying about processed bot mail..."
          echo "[$(date)] 📬 Bot mail received:" \
            | cat - $HOME/goromail/bot.log > $HOME/goromail/temp \
            && mv $HOME/goromail/temp $HOME/goromail/bot.log
          gmail-manager gbot-send 6612105214@vzwpix.com "ats-mailman" \
            "$(cat $HOME/goromail/bot.log)"
          gmail-manager gbot-send andrew.torgesen@gmail.com "ats-mailman" \
            "$(cat $HOME/goromail/bot.log)"
          if [[ ! -z "$(grep 'Calories entry' $HOME/goromail/bot.log)" ]]; then
            echo "Notifying of calorie total..."
            lines="$(wiki-tools --url "${wiki-url}" get --page-id calorie-journal | grep $(printf '%(%Y-%m-%d)T\n' -1))"
            if [[ -z $lines ]]; then
              exit
            fi
            ctotal=0
            clim=1950
            while IFS= read -r line; do
              c=`echo ''${line##* }`
              ctotal=$(( ctotal + c ))
            done <<< "$lines"
            echo $ctotal
            if (( ctotal <= clim )); then
              gmail-manager gbot-send 6612105214@vzwpix.com "ats-ccounterd" \
                "[$(date)] 🗒️ Calorie counter: $ctotal / $clim ✅"
              gmail-manager gbot-send andrew.torgesen@gmail.com "ats-ccounterd" \
                "[$(date)] 🗒️ Calorie counter: $ctotal / $clim ✅"
            else
              gmail-manager gbot-send 6612105214@vzwpix.com "ats-ccounterd" \
                "[$(date)] 🗒️ Calorie counter: $ctotal / $clim - Watch out! 🚨"
              gmail-manager gbot-send andrew.torgesen@gmail.com "ats-ccounterd" \
                "[$(date)] 🗒️ Calorie counter: $ctotal / $clim - Watch out! 🚨"
            fi
          fi
        fi 
        if [[ ! -z "$(cat $HOME/goromail/journal.log)" ]]; then
          echo "Notifying about processed journal mail..."
          echo "[$(date)] 📖 Journal mail received:" \
            | cat - $HOME/goromail/journal.log > $HOME/goromail/temp \
            && mv $HOME/goromail/temp $HOME/goromail/journal.log
          gmail-manager gbot-send 6612105214@vzwpix.com "ats-mailman" \
            "$(cat $HOME/goromail/journal.log)"
          gmail-manager gbot-send andrew.torgesen@gmail.com "ats-mailman" \
            "$(cat $HOME/goromail/journal.log)"
        fi
      '';
      timerCfg = {
        OnBootSec = "5m";
        OnUnitActiveSec = "10m";
      };
    })
    (mkOneshotTimedOrchService {
      name = "ats-grader";
      jobShellScript = writeShellScript "ats-grader" ''
        authm refresh --headless || { >&2 echo "authm refresh error!"; exit 1; }
        tmpdir=$(mktemp -d)
        echo "🔥 Task Cleaning for the Week 🔥" > $tmpdir/out.txt
        echo "" >> $tmpdir/out.txt
        # TODO intelligently choose the year...
        task-tools clean --start-date 2024-01-01 >> $tmpdir/out.txt
        gmail-manager gbot-send 6612105214@vzwpix.com "ats-grader" \
            "$(cat $tmpdir/out.txt)"
        gmail-manager gbot-send andrew.torgesen@gmail.com "ats-grader" \
            "$(cat $tmpdir/out.txt)"
        rm -r $tmpdir
      '';
      timerCfg = {
        OnCalendar = [ "*-*-* 22:00:00" ];
        Persistent = true;
      };
    })
    (mkOneshotTimedOrchService {
      name = "ats-tasks-ranked";
      jobShellScript = writeShellScript "ats-tasks-ranked" ''
        authm refresh --headless || { >&2 echo "authm refresh error!"; exit 1; }
        tmpdir=$(mktemp -d)
        echo "🗓️ Pending Tasks:" > $tmpdir/out.txt
        echo "" >> $tmpdir/out.txt
        task-tools list ranked --no-ids >> $tmpdir/out.txt
        gmail-manager gbot-send 6612105214@vzwpix.com "ats-tasks" \
            "$(cat $tmpdir/out.txt)"
        gmail-manager gbot-send andrew.torgesen@gmail.com "ats-tasks" \
            "$(cat $tmpdir/out.txt)"
        rm -r $tmpdir
      '';
      timerCfg = {
        OnCalendar = [ "*-*-* 07:00:00" ];
        Persistent = true;
      };
    })
    (mkOneshotTimedOrchService {
      name = "ats-prov-tasker";
      jobShellScript = writeShellScript "ats-prov-tasker" ''
        authm refresh --headless || { >&2 echo "authm refresh error!"; exit 1; }
        providence-tasker --wiki-url ${wiki-url} 7 ${anixpkgs.redirects.suppress_all}
        gmail-manager gbot-send 6612105214@vzwpix.com "ats-ptaskerd" \
          "[$(date)] 📖 Happy Sunday! Providence-tasker has deployed for the coming week ✅"
        gmail-manager gbot-send andrew.torgesen@gmail.com "ats-ptaskerd" \
          "[$(date)] 📖 Happy Sunday! Providence-tasker has deployed for the coming week ✅"
      '';
      timerCfg = {
        OnCalendar = [ "Sun *-*-* 08:00:00" ];
        Persistent = false;
      };
    })
    (mkOneshotTimedOrchService {
      name = "ats-rand-journal";
      jobShellScript = writeShellScript "ats-rand-journal" ''
        authm refresh --headless || { >&2 echo "authm refresh error!"; exit 1; }
        tmpdir=$(mktemp -d)
        echo "🖊️ Random Journal Entry of the Day:" > $tmpdir/out.txt
        echo "" >> $tmpdir/out.txt
        wiki-tools --url ${wiki-url} get-rand-journal >> $tmpdir/out.txt
        gmail-manager journal-send 6612105214@vzwpix.com "ats-rand-journal" \
          "$(cat $tmpdir/out.txt)"
        gmail-manager journal-send andrew.torgesen@gmail.com "ats-rand-journal" \
          "$(cat $tmpdir/out.txt)"
        rm -r $tmpdir
      '';
      timerCfg = {
        OnCalendar = [ "*-*-* 06:30:00" ];
        Persistent = true;
      };
    })
  ];
in {
  options.services.ats = { enable = mkEnableOption "enable ATS services"; };

  imports = [ ../../python-packages/orchestrator/module.nix ];

  config = mkIf cfg.enable
    (foldl' (acc: set: recursiveUpdate acc set) { } atsServices);
}
