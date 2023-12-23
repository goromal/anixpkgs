{ pkgs, config, lib, ... }:
with pkgs;
with lib;
let cfg = config.services.orchestratord;
in {
  options.services.orchestratord = with types; {
    enable = mkEnableOption "enable orchestrator daemon";
    rootDir = mkOption {
      type = types.str;
      description = "Root directory for data and configuration";
      default = "/data/andrew/orchestratord";
    };
    threads = mkOption {
      type = types.int;
      description = "Number of concurrent threads to orchestrate";
      default = 2;
    };
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules =
      [ "d  ${cfg.rootDir} - andrew dev" "Z  ${cfg.rootDir} - andrew dev" ];
    systemd.services.orchestratord = {
      enable = true;
      description = "Orchestrator daemon";
      unitConfig = { StartLimitIntervalSec = 0; };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.orchestrator}/bin/orchestratord -n ${
            builtins.toString cfg.threads
          }";
        ReadWritePaths = [ "/" ];
        WorkingDirectory = cfg.rootDir;
        Restart = "always";
        RestartSec = 5;
        User = "andrew";
        Group = "dev";
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}