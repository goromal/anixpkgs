{ pkgs, config, lib, ... }:
let cfg = config.services.orchestratord;
in {
  options.services.orchestratord = {
    enable = lib.mkEnableOption "enable orchestrator daemon";
    user = lib.mkOption {
      type = lib.types.str;
      description = "Daemon-controlling user";
      default = "andrew";
    };
    rootDir = lib.mkOption {
      type = lib.types.str;
      description = "Root directory for data and configuration";
      default = "/data/andrew/orchestratord";
    };
    orchestratorPkg = lib.mkOption {
      type = lib.types.package;
      description = "The orchestrator package to use";
    };
    threads = lib.mkOption {
      type = lib.types.int;
      description = "Number of concurrent threads to orchestrate";
      default = 2;
    };
    pathPkgs = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      description = "Packages to expose to orchestratord's PATH";
      default = [ ];
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d  ${cfg.rootDir} - ${cfg.user} dev"
      "Z  ${cfg.rootDir} - ${cfg.user} dev"
    ];
    systemd.services.orchestratord = {
      enable = true;
      description = "Orchestrator daemon";
      unitConfig = { StartLimitIntervalSec = 0; };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.orchestratorPkg}/bin/orchestratord -n ${
            builtins.toString cfg.threads
          }";
        ReadWritePaths = [ "/" ];
        WorkingDirectory = cfg.rootDir;
        Restart = "always";
        RestartSec = 5;
        User = cfg.user;
        Group = "dev";
      };
      wantedBy = [ "multi-user.target" ];
      path = cfg.pathPkgs;
    };
  };
}
