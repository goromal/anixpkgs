{ pkgs, config, lib, ... }:
with import ../../nixos/dependencies.nix;
let cfg = config.services.tacticald;
in {
  options.services.tacticald = {
    enable = lib.mkEnableOption "enable tactical daemon";
    user = lib.mkOption {
      type = lib.types.str;
      description = "Daemon-controlling user";
      default = "andrew";
    };
    group = lib.mkOption {
      type = lib.types.str;
      description = "Service owner group";
      default = "dev";
    };
    rootDir = lib.mkOption {
      type = lib.types.str;
      description = "Root directory (SYMLINK) for data and configuration";
      default = "/data/andrew/tacticald";
    };
    rootDirSource = lib.mkOption {
      type = lib.types.str;
      description =
        "Root directory (symlinked by rootDir) for data and configuration";
      default = "/data/andrew/data/tacticald";
    };
    tacticalPkg = lib.mkOption {
      type = lib.types.package;
      description = "The tactical package to use";
    };
    statsdPort = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      default = null;
      description = "StatsD port to send metrics to";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules =
      [ "L ${cfg.rootDir} - - - - ${cfg.rootDirSource}" ];
    systemd.services.tacticald = {
      enable = true;
      description = "tactical daemon";
      unitConfig = { StartLimitIntervalSec = 0; };
      serviceConfig = {
        Type = "simple";
        ExecStart =
          "${cfg.tacticalPkg}/bin/tacticald --db-path ${cfg.rootDir}/data.db --storage-path ${cfg.rootDir}/data.json"
          + lib.optionalString (cfg.statsdPort != null)
          " --statsd-port ${builtins.toString cfg.statsdPort}";
        ReadWritePaths = [ "/" ];
        WorkingDirectory = cfg.rootDir;
        Restart = "always";
        RestartSec = 5;
        User = cfg.user;
        Group = cfg.group;
      };
      wantedBy = [ "multi-user.target" ];
    };

    machines.base.runWebServer = true;
    services.nginx.virtualHosts."${config.networking.hostName}.local" = {
      locations."/tactical/" = {
        proxyPass = "http://127.0.0.1:${
            builtins.toString service-ports.tactical.web
          }/tactical/";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };
  };
}
