{
  pkgs,
  config,
  lib,
  ...
}:
with import ../../../nixos/dependencies.nix;
let
  cfg = config.services.la-quiz-web;
in
{
  options.services.la-quiz-web = {
    enable = lib.mkEnableOption "enable LA quiz web server";
    package = lib.mkOption {
      type = lib.types.package;
      description = "The la-quiz-web package to use";
      default = anixpkgs.la_quiz_web;
    };
    dataDir = lib.mkOption {
      type = lib.types.str;
      description = "Data directory for database and maps";
      default = "/data/andrew/la-quiz-web";
    };
    dbPath = lib.mkOption {
      type = lib.types.str;
      description = "Path to SQLite database";
      default = "${cfg.dataDir}/la_quiz.db";
    };
    mapsDir = lib.mkOption {
      type = lib.types.str;
      description = "Directory containing map images";
      default = "${cfg.dataDir}/maps";
    };
    port = lib.mkOption {
      type = lib.types.port;
      description = "Port to run the server on";
      default = service-ports.la-quiz-web;
    };
    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain path for reverse proxy";
      default = "/la-quiz";
    };
  };

  config = lib.mkIf cfg.enable {
    machines.base.webServices = [
      {
        name = "LA Quiz Game";
        path = "/la-quiz/";
        description = "LA geography challenge game";
      }
    ];

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 andrew dev -"
      "d ${cfg.mapsDir} 0755 andrew dev -"
    ];

    systemd.services.la-quiz-web = {
      enable = true;
      description = "LA Geography Quiz Web Server";
      unitConfig = {
        StartLimitIntervalSec = 0;
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/la-quiz-web --port ${builtins.toString cfg.port} --subdomain ${cfg.subdomain} --db-path ${cfg.dbPath} --maps-dir ${cfg.mapsDir}";
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
