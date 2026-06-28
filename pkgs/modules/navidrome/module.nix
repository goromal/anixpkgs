{
  pkgs,
  config,
  lib,
  ...
}:
with import ../../nixos/dependencies.nix;
let
  cfg = config.services.navidrome-ats;
in
{
  options.services.navidrome-ats = {
    enable = lib.mkEnableOption "enable Navidrome music server";
    package = lib.mkOption {
      type = lib.types.package;
      description = "The navidrome package to use";
      default = pkgs.navidrome;
    };
    dataDir = lib.mkOption {
      type = lib.types.str;
      description = "Data directory for the database and cache";
      default = "/data/andrew/data/navidrome";
    };
    musicDir = lib.mkOption {
      type = lib.types.str;
      description = "Directory Navidrome scans for music";
      default = "${cfg.dataDir}/music";
    };
    port = lib.mkOption {
      type = lib.types.port;
      description = "Port to run the server on";
      default = service-ports.navidrome;
    };
    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain path for reverse proxy";
      default = "/navidrome";
    };
  };

  config = lib.mkIf cfg.enable {
    machines.base.webServices = [
      {
        name = "Navidrome";
        path = "${cfg.subdomain}/";
        description = "Personal music streaming server";
        icon = "music";
        faviconSvg = anixpkgs.pkgData.icons.favicons."music".data;
      }
    ];

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 andrew dev -"
      "d ${cfg.musicDir} 0755 andrew dev -"
    ];

    systemd.services.navidrome-ats = {
      enable = true;
      description = "Navidrome Music Server";
      after = [ "network.target" ];
      unitConfig = {
        StartLimitIntervalSec = 0;
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/navidrome --datafolder ${cfg.dataDir} --musicfolder ${cfg.musicDir} --address 127.0.0.1 --port ${builtins.toString cfg.port} --baseurl ${cfg.subdomain}";
        WorkingDirectory = cfg.dataDir;
        ReadWritePaths = [ cfg.dataDir ];
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
