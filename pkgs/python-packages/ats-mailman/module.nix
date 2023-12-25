{ pkgs, config, lib, ... }:
with pkgs;
with lib;
let
  cfg = config.services.ats-mailman;
  greetingScript = writeShellScript "ats-mailman" ''
    set -e
    authm refresh  || { >&2 echo "authm refresh error!"; exit 1; }
    # TODO warn about expiration
    goromail bot --headless
    goromail journal --headless
    if [[ ! -z "$(cat ${cfg.rootDir}/bot.log)" ]]; then
      echo "Notifying about processed bot mail..."
      gmail-manager gbot-send 6612105214@vzwpix.com "ats-mailman" \
        "[$(date)] Processed mail:"
      gmail-manager gbot-send 6612105214@vzwpix.com "ats-mailman" \
        "$(cat ${cfg.rootDir}/bot.log)"
    fi 
    if [[ ! -z "$(cat ${cfg.rootDir}/journal.log)" ]]; then
      echo "Notifying about processed journal mail..."
      gmail-manager gbot-send 6612105214@vzwpix.com "ats-mailman" \
        "[$(date)] Processed journal:"
      gmail-manager gbot-send 6612105214@vzwpix.com "ats-mailman" \
        "$(cat ${cfg.rootDir}/journal.log)"
    fi
  '';
in {
  options.services.ats-mailman = with types; {
    enable = mkEnableOption "enable ATS mailman script";
    rootDir = mkOption {
      type = types.str;
      description = "Root directory for data and configuration";
      default = "/data/andrew/goromail";
    };
    orchestratorPkg = mkOption {
      type = types.package;
      description = "The orchestrator package to use";
    };
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules =
      [ "d  ${cfg.rootDir} - andrew dev" "Z  ${cfg.rootDir} - andrew dev" ];
    systemd.services.ats-mailman = {
      enable = true;
      description = "ATS mailman script";
      unitConfig = { StartLimitIntervalSec = 0; };
      serviceConfig = {
        Type = "simple";
        ExecStart =
          "${cfg.orchestratorPkg}/bin/orchestrator bash 'bash ${greetingScript}'";
        Restart = "always";
        RestartSec = 300;
        ReadWritePaths = [ "${cfg.rootDir}" ];
        WorkingDirectory = cfg.rootDir;
        User = "andrew";
        Group = "dev";
      };
      wantedBy = [ "multi-user.target" ];
      after = [ "ats-greeting.service" ];
    };
  };
}
