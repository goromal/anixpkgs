{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.services.ardurouter;
in
{
  options.services.ardurouter = {
    enable = lib.mkEnableOption "enable ardurouter service";
    package = lib.mkOption {
      type = lib.types.package;
      description = "The ardurouter package to use";
    };
    rootDir = lib.mkOption {
      type = lib.types.str;
      description = "Root service directory";
    };
    interfaceArgs = lib.mkOption {
      type = lib.types.str;
      description = "Interface args to pass to the router";
    };
    user = lib.mkOption {
      type = lib.types.str;
      description = "Service owner user";
    };
    group = lib.mkOption {
      type = lib.types.str;
      description = "Service owner group";
    };
    log = lib.mkOption {
      type = lib.types.bool;
      description = "Whether or not to log all routed messages to stdout";
      default = false;
    };
    tlog = lib.mkOption {
      type = lib.types.bool;
      description = "Whether or not to log telemetry";
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.rootDir} - ${cfg.user} ${cfg.group}"
      "Z ${cfg.rootDir} - ${cfg.user} ${cfg.group}"
    ];
    systemd.services.ardurouter = {
      enable = true;
      description = "Ardurouter service";
      unitConfig = {
        StartLimitIntervalSec = 0;
        LogRateLimitIntervalSec = 0;
        LogRateLimitBurst = 0;
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/mavlink-routerd ${cfg.interfaceArgs} ${
          if cfg.log then "--log ${cfg.rootDir}" else ""
        } ${if cfg.tlog then "--tlog ${cfg.rootDir}" else ""}";
        CPUQuota = "300%";
        Restart = "always";
        RestartSec = 1;
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.rootDir;
      };
      requires = [
        "network.target"
        "sysinit.target"
      ];
      wantedBy = [ "multi-user.target" ];
      # TODO after [ (udev.device) ];
    };
  };
}
