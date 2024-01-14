{ pkgs, config, lib, ... }:
# TODO this is a very bespoke script--adapt or use sparingly
# probably replace the standalone-modules/ and orchestrator/ modules with these home-manager versions
# in a components/ats.nix file (i.e., this file with added configurability, removal of home-manager configs,
# and accommodation of NixOS paths for e.g., coreutils)
with pkgs;
with import ../dependencies.nix { inherit config; };
with anixpkgs;
let
  oPathPkgs = lib.makeBinPath [
    rclone
    wiki-tools
    rcrsync
    mp4
    mp4unite
    goromail
    gmail-parser
    scrape
    authm
    providence-tasker
  ];
  launchOrchestratorScript = writeShellScriptBin "launch-orchestrator" ''
    PATH=$PATH:/usr/bin:${oPathPkgs}
    ${anixpkgs.orchestrator}/bin/orchestratord -n 2
  '';
  greetingScript = writeShellScript "ats-greeting" ''
    sleep 5
    authm refresh --headless 1  || { >&2 echo "authm refresh error!"; exit 1; }
    sleep 5
    gmail-manager gbot-send 6612105214@vzwpix.com "ats-greeting" \
      "[$(date)] 🌞 Hello, world! I'm awake! authm refreshed successfully ✅"
    gmail-manager gbot-send andrew.torgesen@gmail.com "ats-greeting" \
      "[$(date)] 🌞 Hello, world! I'm awake! authm refreshed successfully ✅"
  '';
  mailmanScript = writeShellScript "ats-mailman" ''
    authm refresh --headless 1  || { >&2 echo "authm refresh error!"; exit 1; }
    rcrsync sync configs || { >&2 echo "configs sync error!"; exit 1; }
    # TODO warn about expiration
    goromail --headless 1 bot ${anixpkgs.redirects.suppress_all}
    goromail --headless 1 journal ${anixpkgs.redirects.suppress_all}
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
  provTaskerScript = writeShellScript "ats-ptaskerd" ''
    authm refresh --headless 1  || { >&2 echo "authm refresh error!"; exit 1; }
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
  imports = [ ./base-pkgs.nix ./x86-graphical-pkgs.nix ./x86-rec-pkgs.nix ];
  mods.x86-graphical.standalone = true;
  mods.x86-graphical.homeDir = "/home/andrew";
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
    Install.WantedBy = [ "default.target" ];
  };
  systemd.user.timers.ats-mailman = {
    Unit.Description = "ATS mailman timer";
    Install.WantedBy = [ "timers.target" ];
    Timer = {
      OnBootSec = "5m";
      OnUnitActiveSec = "30m";
      Unit = "ats-mailman.service";
    };
  };
  systemd.user.services.ats-mailman = {
    Unit.Description = "ATS mailman script";
    Install.WantedBy = [ "default.target" ];
    Service = {
      Type = "oneshot";
      ExecStart =
        "${anixpkgs.orchestrator}/bin/orchestrator bash 'bash ${mailmanScript}'";
      ReadWritePaths = [ "/home/andrew" ];
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
    Install.WantedBy = [ "default.target" ];
    Service = {
      Type = "oneshot";
      ExecStart =
        "${anixpkgs.orchestrator}/bin/orchestrator bash 'bash ${provTaskerScript}'";
      ReadWritePaths = [ "/home/andrew" ];
    };
  };
}
