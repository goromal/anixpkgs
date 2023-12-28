{ pkgs, config, lib, ... }:
with pkgs;
with lib;
let
  cfg = config.services.ats-mailman;
  greetingScript = writeShellScript "ats-mailman" ''
    set -e
    authm refresh  || { >&2 echo "authm refresh error!"; exit 1; }
    rcrsync sync configs || { >&2 echo "configs sync error!"; exit 1; }
    # TODO warn about expiration
    goromail --headless 1 bot ${cfg.redirectsPkg.suppress_all}
    goromail --headless 1 journal ${cfg.redirectsPkg.suppress_all}
    if [[ ! -z "$(cat ${cfg.rootDir}/bot.log)" ]]; then
      echo "Notifying about processed bot mail..."
      authm refresh  || { >&2 echo "authm refresh error!"; exit 1; }
      echo "[$(date)] 📬 Bot mail received:" \
        | cat - ${cfg.rootDir}/bot.log > ${cfg.rootDir}/temp \
        && mv ${cfg.rootDir}/temp ${cfg.rootDir}/bot.log
      gmail-manager gbot-send 6612105214@vzwpix.com "ats-mailman" \
        "$(cat ${cfg.rootDir}/bot.log)"
      gmail-manager gbot-send andrew.torgesen@gmail.com "ats-mailman" \
        "$(cat ${cfg.rootDir}/bot.log)"
    fi 
    if [[ ! -z "$(cat ${cfg.rootDir}/journal.log)" ]]; then
      echo "Notifying about processed journal mail..."
      authm refresh  || { >&2 echo "authm refresh error!"; exit 1; }
      echo "[$(date)] 📖 Journal mail received:" \
        | cat - ${cfg.rootDir}/journal.log > ${cfg.rootDir}/temp \
        && mv ${cfg.rootDir}/temp ${cfg.rootDir}/journal.log
      gmail-manager gbot-send 6612105214@vzwpix.com "ats-mailman" \
        "$(cat ${cfg.rootDir}/journal.log)"
      gmail-manager gbot-send andrew.torgesen@gmail.com "ats-mailman" \
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
    redirectsPkg = mkOption {
      type = types.attrs;
      description = "The redirects package to use";
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
        RestartSec = 1800; # every half hour
        ReadWritePaths = [ "/data/andrew" ];
        WorkingDirectory = cfg.rootDir;
        User = "andrew";
        Group = "dev";
      };
      wantedBy = [ "multi-user.target" ];
      after = [ "ats-greeting.service" ];
    };
  };
}
