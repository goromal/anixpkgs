{
  pkgs,
  config,
  lib,
  ...
}:
with import ../../../nixos/dependencies.nix;
let
  globalCfg = config.machines.base;
  cfg = config.services.disciple;
in
{
  options.services.disciple = {
    enable = lib.mkEnableOption "enable Book of Mormon study tool";
    package = lib.mkOption {
      type = lib.types.package;
      description = "The disciple package to use";
      default = anixpkgs.disciple;
    };
    dataDir = lib.mkOption {
      type = lib.types.str;
      description = "Data directory for database and uploads";
      default = "${globalCfg.homeDir}/data/disciple";
    };
    dbPath = lib.mkOption {
      type = lib.types.str;
      description = "Path to SQLite database";
      default = "${cfg.dataDir}/disciple.db";
    };
    port = lib.mkOption {
      type = lib.types.port;
      description = "Port to run the server on";
      default = service-ports.disciple;
    };
    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain path for reverse proxy";
      default = "/disciple";
    };
  };

  config = lib.mkIf cfg.enable {
    machines.base.webServices = [
      {
        name = "Disciple";
        path = "/disciple/";
        description = "Book of Mormon Christ-reference study tool";
        icon = "book-open";
        faviconSvg = null;
      }
    ];

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 andrew dev -"
    ];

    systemd.services.disciple = {
      enable = true;
      description = "Book of Mormon Study Web Server";
      unitConfig = {
        StartLimitIntervalSec = 0;
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/disciple --port ${builtins.toString cfg.port} --subdomain ${cfg.subdomain} --db-path ${cfg.dbPath}";
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
