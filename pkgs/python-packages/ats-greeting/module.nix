{ pkgs, config, lib, ... }:
with pkgs;
with lib;
let cfg = config.services.ats-greeting;
greetingScript = writeShellScript "ats-greeting" ''
  authm refresh  || { >&2 echo "authm refresh error!"; exit 1; }
  gmail-manager gbot-send 6612105214@vzwpix.com "ats-greeting" \
    "🌞 Hello, world! I'm awake! authm refreshed successfully ✅"
'';
in {
  options.services.ats-greeting = with types; {
    enable = mkEnableOption "enable ATS greeting script";
  };

  config = mkIf cfg.enable {
    systemd.services.ats-greeting = {
      enable = true;
      description = "ATS greeting script";
      unitConfig = { StartLimitIntervalSec = 0; };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.orchestrator}/bin/orchestrator bash 'bash ${greetingScript}'";
        Restart = "always";
        RestartSec = 5;
        User = "andrew";
        Group = "dev";
      };
      wantedBy = [ "multi-user.target" ];
      requires = [ "orchestratord.service" ];
    };
  };
}