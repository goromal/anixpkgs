{ pkgs, config, lib, ... }:
# TODO This is a very bespoke config--adapt or use sparingly
# probably replace the standalone-modules/ and orchestrator/ modules with these home-manager versions
# in a components/ats.nix file (i.e., this file with added configurability, removal of home-manager configs,
# and accommodation of NixOS paths for e.g., coreutils)
# NOTE: When running these units as user processes on a headless server, you'll want to edit
#       /etc/systemd/logind.conf to have the entry KillUserProcesses=no (and restart systemd-logind)
#       in order to avoid having systemd kill the processes when you're logged out.
with pkgs;
with import ../dependencies.nix { inherit config; };
with anixpkgs;
let
  cfg = config.mods.opts;
  oPathPkgs = let
    ats-rcrsync = rcrsync.override { cloudDirs = cfg.cloudDirs; };
    ats-authm = authm.override { rcrsync = ats-rcrsync; };
  in lib.makeBinPath [
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
  launchOrchestratorScript = writeShellScriptBin "launch-orchestrator" ''
    PATH=$PATH:/usr/bin:${oPathPkgs} ${anixpkgs.orchestrator}/bin/orchestratord -n 2
  '';
  greetingScript = writeShellScript "ats-greeting" ''
    sleep 5
    authm refresh --headless || { >&2 echo "authm refresh error!"; exit 1; }
    sleep 5
    gmail-manager gbot-send 6612105214@vzwpix.com "ats-greeting" \
      "[$(date)] 🌞 Hello, world! I'm awake! authm refreshed successfully ✅"
    gmail-manager gbot-send andrew.torgesen@gmail.com "ats-greeting" \
      "[$(date)] 🌞 Hello, world! I'm awake! authm refreshed successfully ✅"
  '';
  mailmanScript = writeShellScript "ats-mailman" ''
    authm refresh --headless || { >&2 echo "authm refresh error!"; exit 1; }
    rcrsync sync configs || { >&2 echo "configs sync error!"; exit 1; }
    # TODO warn about expiration
    goromail --headless bot ${anixpkgs.redirects.suppress_all}
    goromail --headless journal ${anixpkgs.redirects.suppress_all}
    if [[ ! -z "$(cat /home/andrew/goromail/bot.log)" ]]; then
      echo "Notifying about processed bot mail..."
      echo "[$(date)] 📬 Bot mail received:" \
        | cat - /home/andrew/goromail/bot.log > /home/andrew/goromail/temp \
        && mv /home/andrew/goromail/temp /home/andrew/goromail/bot.log
      gmail-manager gbot-send 6612105214@vzwpix.com "ats-mailman" \
        "$(cat /home/andrew/goromail/bot.log)"
      gmail-manager gbot-send andrew.torgesen@gmail.com "ats-mailman" \
        "$(cat /home/andrew/goromail/bot.log)"
      if [[ ! -z "$(grep 'Calories entry' /home/andrew/goromail/bot.log)" ]]; then
        echo "Notifying of calorie total..."
        lines="$(wiki-tools get --page-id calorie-journal | grep $(printf '%(%Y-%m-%d)T\n' -1))"
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
    if [[ ! -z "$(cat /home/andrew/goromail/journal.log)" ]]; then
      echo "Notifying about processed journal mail..."
      echo "[$(date)] 📖 Journal mail received:" \
        | cat - /home/andrew/goromail/journal.log > /home/andrew/goromail/temp \
        && mv /home/andrew/goromail/temp /home/andrew/goromail/journal.log
      gmail-manager gbot-send 6612105214@vzwpix.com "ats-mailman" \
        "$(cat /home/andrew/goromail/journal.log)"
      gmail-manager gbot-send andrew.torgesen@gmail.com "ats-mailman" \
        "$(cat /home/andrew/goromail/journal.log)"
    fi
  '';
  graderScript = writeShellScript "ats-grader" ''
    authm refresh --headless || { >&2 echo "authm refresh error!"; exit 1; }
    rcrsync sync data || { >&2 echo "data sync error!"; exit 1; }
    tmpdir=$(mktemp -d)
    echo "🔥 Tasking Grades for the Week 🔥" > $tmpdir/out.txt
    echo "" >> $tmpdir/out.txt
    task-tools grader --start-date 2024-01-01 >> $tmpdir/out.txt
    gmail-manager gbot-send 6612105214@vzwpix.com "ats-grader" \
        "$(cat $tmpdir/out.txt)"
    gmail-manager gbot-send andrew.torgesen@gmail.com "ats-grader" \
        "$(cat $tmpdir/out.txt)"
    rm -r $tmpdir
    rcrsync sync data || { >&2 echo "data sync error!"; exit 1; }

  '';
  taskP0Script = writeShellScript "ats-p0-tasks" ''
    authm refresh --headless || { >&2 echo "authm refresh error!"; exit 1; }
    tmpdir=$(mktemp -d)
    echo "❗0️⃣❗Pending P0 Tasks for the Day:" > $tmpdir/out.txt
    echo "" >> $tmpdir/out.txt
    task-tools list p0 --no-ids >> $tmpdir/out.txt
    gmail-manager gbot-send 6612105214@vzwpix.com "ats-tasks" \
        "$(cat $tmpdir/out.txt)"
    gmail-manager gbot-send andrew.torgesen@gmail.com "ats-tasks" \
        "$(cat $tmpdir/out.txt)"
    rm -r $tmpdir
  '';
  taskP1Script = writeShellScript "ats-p1-tasks" ''
    authm refresh --headless || { >&2 echo "authm refresh error!"; exit 1; }
    tmpdir=$(mktemp -d)
    echo "💡1️⃣💡 Pending P1 Tasks for the Week:" > $tmpdir/out.txt
    echo "" >> $tmpdir/out.txt
    task-tools list p1 --no-ids >> $tmpdir/out.txt
    gmail-manager gbot-send 6612105214@vzwpix.com "ats-tasks" \
        "$(cat $tmpdir/out.txt)"
    gmail-manager gbot-send andrew.torgesen@gmail.com "ats-tasks" \
        "$(cat $tmpdir/out.txt)"
    rm -r $tmpdir
  '';
  taskP2Script = writeShellScript "ats-p2-tasks" ''
    authm refresh --headless || { >&2 echo "authm refresh error!"; exit 1; }
    tmpdir=$(mktemp -d)
    echo "🗓️2️⃣🗓️ Pending P2 Tasks for the Month:" > $tmpdir/out.txt
    echo "" >> $tmpdir/out.txt
    task-tools list p2 --no-ids >> $tmpdir/out.txt
    gmail-manager gbot-send 6612105214@vzwpix.com "ats-tasks" \
        "$(cat $tmpdir/out.txt)"
    gmail-manager gbot-send andrew.torgesen@gmail.com "ats-tasks" \
        "$(cat $tmpdir/out.txt)"
    rm -r $tmpdir
  '';
  taskLateScript = writeShellScript "ats-late-tasks" ''
    authm refresh --headless || { >&2 echo "authm refresh error!"; exit 1; }
    tmpdir=$(mktemp -d)
    echo "🚨*️⃣🚨 LATE Tasks:" > $tmpdir/out.txt
    echo "" >> $tmpdir/out.txt
    task-tools list late --no-ids >> $tmpdir/out.txt
    gmail-manager gbot-send 6612105214@vzwpix.com "ats-tasks" \
        "$(cat $tmpdir/out.txt)"
    gmail-manager gbot-send andrew.torgesen@gmail.com "ats-tasks" \
        "$(cat $tmpdir/out.txt)"
    rm -r $tmpdir
  '';
  provTaskerScript = writeShellScript "ats-ptaskerd" ''
    authm refresh --headless || { >&2 echo "authm refresh error!"; exit 1; }
    providence-tasker 7 ${anixpkgs.redirects.suppress_all}
    gmail-manager gbot-send 6612105214@vzwpix.com "ats-ptaskerd" \
      "[$(date)] 📖 Happy Sunday! Providence-tasker has deployed for the coming week ✅"
    gmail-manager gbot-send andrew.torgesen@gmail.com "ats-ptaskerd" \
      "[$(date)] 📖 Happy Sunday! Providence-tasker has deployed for the coming week ✅"
  '';
in {
  home.username = "andrew";
  home.homeDirectory = "/home/andrew";
  home.stateVersion = "23.05";
  programs.home-manager.enable = true;
  imports =
    [ ./opts.nix ./base-pkgs.nix ./x86-graphical-pkgs.nix ./x86-rec-pkgs.nix ];
  mods.opts.standalone = lib.mkForce true;
  mods.opts.homeDir = lib.mkForce "/home/andrew";
  home.packages = [
    (writeShellScriptBin "ats-load-services" ''
      mkdir -p /home/andrew/goromail
      systemctl --user daemon-reload
      systemctl --user restart orchestratord.service
      systemctl --user enable ats-greeting.timer
      systemctl --user start ats-greeting.timer
      systemctl --user enable ats-mailman.timer
      systemctl --user start ats-mailman.timer
      systemctl --user enable ats-ptaskerd.timer
      systemctl --user start ats-ptaskerd.timer
      systemctl --user enable ats-grader.timer
      systemctl --user start ats-grader.timer
      systemctl --user enable ats-taskP0.timer
      systemctl --user start ats-taskP0.timer
      systemctl --user enable ats-taskP1.timer
      systemctl --user start ats-taskP1.timer
      systemctl --user enable ats-taskP2.timer
      systemctl --user start ats-taskP2.timer
      systemctl --user enable ats-taskLate.timer
      systemctl --user start ats-taskLate.timer
      loginctl enable-linger andrew
    '')
    (writeShellScriptBin "jfu" ''
      journalctl --user -fu $@
    '')
    (writeShellScriptBin "sctl" ''
      systemctl --user $@
    '')
  ];
  systemd.user.services.orchestratord = {
    Unit = { Description = "Orchestrator daemon"; };
    Service = {
      Type = "simple";
      ExecStart = "${launchOrchestratorScript}/bin/launch-orchestrator";
      Restart = "always";
    };
    Install.WantedBy = [ "default.target" ];
  };
  systemd.user.timers.ats-greeting = {
    Unit = { Description = "ATS greeting timer"; };
    Timer = {
      OnBootSec = "1m";
      Persistent = false;
      Unit = "ats-greeting.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };
  systemd.user.services.ats-greeting = {
    Unit = { Description = "ATS greeting script"; };
    Service = {
      Type = "oneshot";
      ExecStart =
        "${anixpkgs.orchestrator}/bin/orchestrator bash 'bash ${greetingScript}'";
      Restart = "on-failure";
      ReadWritePaths = [ "/home/andrew" ];
    };
  };
  systemd.user.timers.ats-mailman = {
    Unit.Description = "ATS mailman timer";
    Install.WantedBy = [ "timers.target" ];
    Timer = {
      OnBootSec = "5m";
      OnUnitActiveSec = "10m";
      Unit = "ats-mailman.service";
    };
  };
  systemd.user.services.ats-mailman = {
    Unit.Description = "ATS mailman script";
    Service = {
      Type = "oneshot";
      ExecStart =
        "${anixpkgs.orchestrator}/bin/orchestrator bash 'bash ${mailmanScript}'";
      ReadWritePaths = [ "/home/andrew" ];
    };
  };
  systemd.user.timers.ats-grader = {
    Unit.Description = "ATS grader timer";
    Install.WantedBy = [ "timers.target" ];
    Timer = {
      OnCalendar = [ "*-*-* 22:00:00" ];
      Persistent = false;
      Unit = "ats-grader.service";
    };
  };
  systemd.user.services.ats-grader = {
    Unit.Description = "ATS grader script";
    Service = {
      Type = "oneshot";
      ExecStart =
        "${anixpkgs.orchestrator}/bin/orchestrator bash 'bash ${graderScript}'";
      ReadWritePaths = [ "/" ];
    };
  };
  systemd.user.timers.ats-taskP0 = {
    Unit.Description = "ATS taskP0 timer";
    Install.WantedBy = [ "timers.target" ];
    Timer = {
      OnCalendar = [ "*-*-* 07:00:00" ];
      Persistent = false;
      Unit = "ats-taskP0.service";
    };
  };
  systemd.user.services.ats-taskP0 = {
    Unit.Description = "ATS taskP0 script";
    Service = {
      Type = "oneshot";
      ExecStart =
        "${anixpkgs.orchestrator}/bin/orchestrator bash 'bash ${taskP0Script}'";
      ReadWritePaths = [ "/" ];
    };
  };
  systemd.user.timers.ats-taskP1 = {
    Unit.Description = "ATS taskP1 timer";
    Install.WantedBy = [ "timers.target" ];
    Timer = {
      OnCalendar = [ "*-*-* 07:01:00" ];
      Persistent = false;
      Unit = "ats-taskP1.service";
    };
  };
  systemd.user.services.ats-taskP1 = {
    Unit.Description = "ATS taskP1 script";
    Service = {
      Type = "oneshot";
      ExecStart =
        "${anixpkgs.orchestrator}/bin/orchestrator bash 'bash ${taskP1Script}'";
      ReadWritePaths = [ "/" ];
    };
  };
  systemd.user.timers.ats-taskP2 = {
    Unit.Description = "ATS taskP2 timer";
    Install.WantedBy = [ "timers.target" ];
    Timer = {
      OnCalendar = [ "*-*-* 07:02:00" ];
      Persistent = false;
      Unit = "ats-taskP2.service";
    };
  };
  systemd.user.services.ats-taskP2 = {
    Unit.Description = "ATS taskP2 script";
    Service = {
      Type = "oneshot";
      ExecStart =
        "${anixpkgs.orchestrator}/bin/orchestrator bash 'bash ${taskP2Script}'";
      ReadWritePaths = [ "/" ];
    };
  };
  systemd.user.timers.ats-taskLate = {
    Unit.Description = "ATS taskLate timer";
    Install.WantedBy = [ "timers.target" ];
    Timer = {
      OnCalendar = [ "*-*-* 07:03:00" "*-*-* 20:03:00" ];
      Persistent = false;
      Unit = "ats-taskLate.service";
    };
  };
  systemd.user.services.ats-taskLate = {
    Unit.Description = "ATS taskLate script";
    Service = {
      Type = "oneshot";
      ExecStart =
        "${anixpkgs.orchestrator}/bin/orchestrator bash 'bash ${taskLateScript}'";
      ReadWritePaths = [ "/" ];
    };
  };
  systemd.user.timers.ats-ptaskerd = {
    Unit.Description = "ATS ptaskerd timer";
    Install.WantedBy = [ "timers.target" ];
    Timer = {
      OnCalendar = [ "Sun *-*-* 08:00:00" ];
      Persistent = false;
      Unit = "ats-ptaskerd.service";
    };
  };
  systemd.user.services.ats-ptaskerd = {
    Unit.Description = "ATS ptaskerd script";
    Service = {
      Type = "oneshot";
      ExecStart =
        "${anixpkgs.orchestrator}/bin/orchestrator bash 'bash ${provTaskerScript}'";
      ReadWritePaths = [ "/home/andrew" ];
    };
  };
}
