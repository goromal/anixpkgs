{ pkgs, config, lib, ... }:
with import ../../nixos/dependencies.nix;
let
  globalCfg = config.machines.base;
  cfg = config.services.ats;
  wiki-url = if globalCfg.serveNotesWiki then
    "http://localhost:${builtins.toString globalCfg.notesWikiPort}"
  else
    "https://notes.andrewtorgesen.com";
  atsudo = pkgs.writeShellScriptBin "atsudo" ''
    args=""
    for word in "$@"; do
      args+="$word "
    done
    args=''${args% }
    sudo -S $args < $HOME/secrets/ats/p.txt 2>/dev/null
  '';
  oPathPkgs = with anixpkgs;
    let
      ats-rcrsync = rcrsync.override { cloudDirs = globalCfg.cloudDirs; };
      ats-authm = authm.override { rcrsync = ats-rcrsync; };
    in with pkgs; [
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
  atsServiceDefs = [
    {
      name = "ats-greeting";
      jobShellScript = pkgs.writeShellScript "ats-greeting" ''
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
    }
    {
      name = "ats-triaging";
      jobShellScript = pkgs.writeShellScript "ats-triaging" ''
        authm refresh --headless || { >&2 echo "authm refresh error!"; exit 1; }
        rcrsync sync configs || { >&2 echo "configs sync error!"; exit 1; }
        goromail --wiki-url ${wiki-url} --headless annotate-triage-pages ${anixpkgs.redirects.suppress_all}
        if [[ ! -z "$(cat $HOME/goromail/annotate.log)" ]]; then
          echo "Notifying about processed triage pages..."
          echo "[$(date)] 🧮 Triage Calculations:" \
            | cat - $HOME/goromail/annotate.log > $HOME/goromail/temp2 \
            && mv $HOME/goromail/temp2 $HOME/goromail/annotate.log
          gmail-manager gbot-send 6612105214@vzwpix.com "ats-triaging" \
            "$(cat $HOME/goromail/annotate.log)"
          gmail-manager gbot-send andrew.torgesen@gmail.com "ats-triaging" \
            "$(cat $HOME/goromail/annotate.log)"
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
        authm refresh --headless || { >&2 echo "authm refresh error!"; exit 1; }
        rcrsync sync configs || { >&2 echo "configs sync error!"; exit 1; }
        # TODO warn about expiration
        goromail --wiki-url ${wiki-url} --headless bot ${anixpkgs.redirects.suppress_all}
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
    }
    {
      name = "ats-grader";
      jobShellScript = pkgs.writeShellScript "ats-grader" ''
        authm refresh --headless || { >&2 echo "authm refresh error!"; exit 1; }
        tmpdir=$(mktemp -d)
        echo "🧹 Daily Task Cleaning 🧹" > $tmpdir/out.txt
        echo "" >> $tmpdir/out.txt
        current_year=$(date +"%Y")
        task-tools clean --start-date "''${current_year}-01-01" >> $tmpdir/out.txt
        gmail-manager gbot-send 6612105214@vzwpix.com "ats-grader" \
            "$(cat $tmpdir/out.txt)"
        gmail-manager gbot-send andrew.torgesen@gmail.com "ats-grader" \
            "$(cat $tmpdir/out.txt)"
        rm -r $tmpdir
      '';
      timerCfg = {
        OnCalendar = [ "*-*-* 06:00:00" ];
        Persistent = true;
      };
    }
    {
      name = "ats-tasks-ranked";
      jobShellScript = pkgs.writeShellScript "ats-tasks-ranked" ''
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
    }
    {
      name = "ats-prov-tasker";
      jobShellScript = pkgs.writeShellScript "ats-prov-tasker" ''
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
    }
    {
      name = "ats-rand-journal";
      jobShellScript = pkgs.writeShellScript "ats-rand-journal" ''
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
    }
  ];
  atsServices = ([
    {
      environment.systemPackages = with pkgs; [
        atsudo
        (let
          servicelist = builtins.concatStringsSep "/"
            (map (x: "${x.name}.service") atsServiceDefs);
          triggerscript = ./atstrigger.py;
        in writeShellScriptBin "atstrigger" ''
          servicelist="${builtins.toString servicelist}"
          tmpdir=$(mktemp -d)
          ${python3}/bin/python ${triggerscript} "$servicelist" 2> $tmpdir/selection
          serviceselection=$(cat $tmpdir/selection)
          rm -r $tmpdir
          if [[ ! -z "$serviceselection" ]]; then
            echo "sudo systemctl restart ''${serviceselection}"
            ${atsudo}/bin/atsudo systemctl restart ''${serviceselection}
          fi
        '')
        (writeShellScriptBin "atsrefresh" ''
          ${atsudo}/bin/atsudo systemctl stop orchestratord
          authm refresh --headless --force && rcrsync override secrets
          ${atsudo}/bin/atsudo systemctl start orchestratord
        '')
      ];
    }
    {
      services.orchestratord = {
        enable = true;
        orchestratorPkg = anixpkgs.orchestrator;
        pathPkgs = oPathPkgs;
      };
    }
    {
      security.sudo.extraConfig = ''
        Defaults    timestamp_timeout=0
      '';
    }
  ] ++ (map (x: (mkOneshotTimedOrchService x)) atsServiceDefs));
in {
  options.services.ats = { enable = lib.mkEnableOption "enable ATS services"; };

  imports = [ ../../python-packages/orchestrator/module.nix ];

  config = lib.mkIf cfg.enable
    (builtins.foldl' (acc: set: lib.recursiveUpdate acc set) { } atsServices);
}
