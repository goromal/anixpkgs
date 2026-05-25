{
  pkgs,
  config,
  lib,
  ...
}:
with import ../../../nixos/dependencies.nix;
let
  globalCfg = config.machines.base;
  cfg = config.services.ttvdserver;
in
{
  options.services.ttvdserver = {
    enable = lib.mkEnableOption "enable TTVD server";
    package = lib.mkOption {
      type = lib.types.package;
      description = "The ttvdserver package to use";
      default = anixpkgs.ttvdserver;
    };
    port = lib.mkOption {
      type = lib.types.port;
      description = "Port to run the server on";
      default = service-ports.ttvd;
    };
    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain path for reverse proxy";
      default = "/ttvd";
    };
  };

  config = lib.mkIf cfg.enable {
    machines.base.webServices = [
      {
        name = "TTVD";
        path = "/ttvd/";
        description = "TikTok video downloader";
      }
    ];

    systemd.services.ttvdserver = {
      enable = true;
      description = "TTVD Web Server";
      unitConfig = {
        StartLimitIntervalSec = 0;
      };
      serviceConfig = {
        Type = "simple";
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${globalCfg.homeDir}/configs/TikTokDownloader";
        ExecStart = "${cfg.package}/bin/ttvdserver --port ${builtins.toString cfg.port} --subdomain ${cfg.subdomain}";
        ReadWritePaths = [ "/tmp/ttvd" "${globalCfg.homeDir}/configs/TikTokDownloader" ];
        WorkingDirectory = globalCfg.homeDir;
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
          proxy_read_timeout 300s;
          proxy_connect_timeout 10s;
        '';
      };
    };
  };
}
