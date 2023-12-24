{ pkgs, config, lib, ... }:
with pkgs;
with lib;
let
  cfg = config.services.ats-mailman;
  greetingScript = writeShellScript "ats-greeting" ''
    set -e
    authm refresh  || { >&2 echo "authm refresh error!"; exit 1; }
    # TODO warn about expiration
    goromail bot --headless
    goromail journal --headless
    # TODO! read logs and notify
    
    
    
    gmail-manager gbot-send 6612105214@vzwpix.com "ats-greeting" \
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
    systemd.services.ats-greeting = {
      enable = true;
      description = "ATS greeting script";
      unitConfig = { StartLimitIntervalSec = 0; };
      serviceConfig = {
        Type = "simple";
        ExecStart =
          "${cfg.orchestratorPkg}/bin/orchestrator bash 'bash ${greetingScript}'";
        Restart = "no";
        User = "andrew";
        Group = "dev";
      };
      wantedBy = [ "multi-user.target" ];
      after = [ "orchestratord.service" ];
    };
  };
}
