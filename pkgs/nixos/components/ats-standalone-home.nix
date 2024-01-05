{ pkgs, config, lib, ... }:
# TODO this is a very bespoke script--adapt or use sparingly
with pkgs;
with import ../dependencies.nix { inherit config; };
with anixpkgs;
let
  oPathPkgs = lib.makeBinPath [ rclone wiki-tools rcrsync mp4 mp4unite goromail gmail-parser scrape authm ];
  greetingScript = writeShellScript "ats-greeting" ''
    sleep 5
    authm refresh --headless 1  || { >&2 echo "authm refresh error!"; exit 1; }
    sleep 5
    gmail-manager gbot-send 6612105214@vzwpix.com "ats-greeting" \
      "[$(date)] 🌞 Hello, world! I'm awake! authm refreshed successfully ✅"
    gmail-manager gbot-send andrew.torgesen@gmail.com "ats-greeting" \
      "[$(date)] 🌞 Hello, world! I'm awake! authm refreshed successfully ✅"
  '';
in {
  systemd.user.services.orchestratord = {
    Unit = {
      Description = "Orchestrator daemon";
    };
    Service = {
      Type = "simple";
      ExecStart = "PATH=$PATH:/usr/bin:${oPathPkgs} ${anixpkgs.orchestrator}/bin/orchestratord -n 2";
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
}
