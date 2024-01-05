{ pkgs, config, lib, ... }:
# TODO this is a very bespoke script--adapt or use sparingly
# probably replace the standalone-modules/ and orchestrator/ modules with these home-manager versions
# in a components/ats.nix file (i.e., this file with added configurability, removal of home-manager configs,
# and accommodation of NixOS paths for e.g., coreutils)
with pkgs;
with import ../dependencies.nix { inherit config; };
with anixpkgs;
let
  oPathPkgs = lib.makeBinPath [ rclone wiki-tools rcrsync mp4 mp4unite goromail gmail-parser scrape authm ];
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
  counterScript = writeShellScript "ats-ccounterd" ''
    authm refresh --headless 1  || { >&2 echo "authm refresh error!"; exit 1; }
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
  '';
in {
  home.username = "andrew";
  home.homeDirectory = "/home/andrew";
  home.stateVersion = "23.05";
  programs.home-manager.enable = true;
  imports = [
    ./base-pkgs.nix
    ./x86-graphical-pkgs.nix
  ];
  mods.x86-graphical.standalone = true;
  mods.x86-graphical.homeDir = "/home/andrew";
  systemd.user.services.orchestratord = {
    Unit = {
      Description = "Orchestrator daemon";
    };
    Service = {
      Type = "simple";
      ExecStart = "${launchOrchestratorScript}/bin/launch-orchestrator";
      Restart = "always";
    };
    Install.WantedBy = [ "default.target" ];
  };
  systemd.user.timers.ats-greeting = {
    Unit = {
      Description = "ATS greeting timer";
    };
    Timer = {
      OnBootSec = "1m";
      Persistent = true;
      Unit = "ats-greeting.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };
  systemd.user.services.ats-greeting = {
    Unit = {
      Description = "ATS greeting script";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${anixpkgs.orchestrator}/bin/orchestrator bash 'bash ${greetingScript}'";
      Restart = "on-failure";
      ReadWritePaths = [ "/home/andrew" ];
    };
    Install.WantedBy = [ "default.target" ];
  };
  # TODO ats-mailman
  systemd.user.timers.ats-ccounterd = {
    Unit = {
      Description = "ATS ccounterd timer";
    };
    Timer = {
      OnCalendar = [ "*-*-* 10:00:00" "*-*-* 14:00:00" "*-*-* 20:00:00" ];
      # triggers the service immediately if it missed the last start time
      Persistent = true;
      Unit = "ats-ccounterd.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };
  systemd.user.services.ats-ccounterd = {
    Unit.Description = "ATS ccounterd script";
    Install.WantedBy = [ "default.target" ];
    Service = {
      Type = "oneshot";
      ExecStart = "${anixpkgs.orchestrator}/bin/orchestrator bash 'bash ${counterScript}'";
      ReadWritePaths = [ "/home/andrew" ];
    };
  };
}
