{
  pkgs,
  config,
  lib,
  ...
}:
with import ../../../nixos/dependencies.nix;
let
  globalCfg = config.machines.base;
  cfg = config.services.vdlserver;
in
{
  options.services.vdlserver = {
    enable = lib.mkEnableOption "enable Video Downloader server";
    package = lib.mkOption {
      type = lib.types.package;
      description = "The vdlserver package to use";
      default = anixpkgs.vdlserver;
    };
    port = lib.mkOption {
      type = lib.types.port;
      description = "Port to run the server on";
      default = service-ports.videodl;
    };
    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain path for reverse proxy";
      default = "/videodl";
    };
  };

  config = lib.mkIf cfg.enable {
    machines.base.webServices = [
      {
        name = "Video Downloader";
        path = "/videodl/";
        description = "Download videos from YouTube, TikTok, and more";
        icon = "download";
        faviconSvg = anixpkgs.pkgData.icons.favicons.download.data;
      }
    ];

    systemd.services.vdlserver = {
      enable = true;
      description = "Video Downloader Web Server";
      unitConfig = {
        StartLimitIntervalSec = 0;
      };
      serviceConfig = {
        Type = "simple";
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${globalCfg.homeDir}/configs/VideoDownloader";
        ExecStart = "${cfg.package}/bin/vdlserver --port ${builtins.toString cfg.port} --subdomain ${cfg.subdomain}";
        ReadWritePaths = [
          "/tmp"
          "${globalCfg.homeDir}/configs"
        ];
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
