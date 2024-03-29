{ pkgs, config, lib, ... }:
with pkgs;
with lib;
let
  cfg = config.services.ats-greeting;
  greetingScript = writeShellScript "ats-greeting" ''
    sleep 5
    authm refresh --headless || { >&2 echo "authm refresh error!"; exit 1; }
    sleep 5
    gmail-manager gbot-send 6612105214@vzwpix.com "ats-greeting" \
      "[$(date)] 🌞 Hello, world! I'm awake! authm refreshed successfully ✅"
    gmail-manager gbot-send andrew.torgesen@gmail.com "ats-greeting" \
      "[$(date)] 🌞 Hello, world! I'm awake! authm refreshed successfully ✅"
  '';
in {
  options.services.ats-greeting = with types; {
    enable = mkEnableOption "enable ATS greeting script";
    orchestratorPkg = mkOption {
      type = types.package;
      description = "The orchestrator package to use";
    };
  };

  config = mkIf cfg.enable {
    systemd.timers.ats-greeting = {
      wantedBy = [ "timers.target" ];
      after = [ "orchestratord.service" ];
      timerConfig = {
        OnBootSec = "1m";
        Unit = "ats-greeting.service";
      };
    };
    systemd.services.ats-greeting = {
      enable = true;
      description = "ATS greeting script";
      script =
        "${cfg.orchestratorPkg}/bin/orchestrator bash 'bash ${greetingScript}'";
      serviceConfig = {
        Type = "oneshot";
        Restart = "on-failure";
        ReadWritePaths = [ "/data/andrew" ];
        User = "andrew";
        Group = "dev";
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}
