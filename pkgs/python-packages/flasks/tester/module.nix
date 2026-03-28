{
  pkgs,
  config,
  lib,
  ...
}:
with import ../../../nixos/dependencies.nix;
let
  globalCfg = config.machines.base;
  cfg = config.services.tester;
in
{
  options.services.tester = {
    enable = lib.mkEnableOption "enable self-test exam tool";
    package = lib.mkOption {
      type = lib.types.package;
      description = "The tester package to use";
      default = anixpkgs.tester;
    };
    dataDir = lib.mkOption {
      type = lib.types.str;
      description = "Data directory for database and uploads";
      default = "${globalCfg.homeDir}/data/tester";
    };
    dbPath = lib.mkOption {
      type = lib.types.str;
      description = "Path to SQLite database";
      default = "${cfg.dataDir}/tester.db";
    };
    port = lib.mkOption {
      type = lib.types.port;
      description = "Port to run the server on";
      default = service-ports.tester;
    };
    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain path for reverse proxy";
      default = "/tester";
    };
  };

  config = lib.mkIf cfg.enable {
    machines.base.webServices = [
      {
        name = "Tester";
        path = "/tester/";
        description = "Self-testing and exam tool";
      }
    ];

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 andrew dev -"
    ];

    systemd.services.tester = {
      enable = true;
      description = "Self-Test Exam Web Server";
      unitConfig = {
        StartLimitIntervalSec = 0;
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/tester --port ${builtins.toString cfg.port} --subdomain ${cfg.subdomain} --db-path ${cfg.dbPath} --data-dir ${cfg.dataDir}";
        ReadWritePaths = [ "/" ];
        WorkingDirectory = cfg.dataDir;
        Restart = "always";
        RestartSec = 5;
        User = "andrew";
        Group = "dev";
      };
      wantedBy = [ "multi-user.target" ];
    };

    machines.base.runWebServer = true;
    services.nginx.virtualHosts."${config.networking.hostName}.local" = {
      locations."${cfg.subdomain}/" = {
        proxyPass = "http://127.0.0.1:${builtins.toString cfg.port}${cfg.subdomain}/";
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
