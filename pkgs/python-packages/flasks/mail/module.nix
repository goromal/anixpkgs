{
  pkgs,
  config,
  lib,
  ...
}:
with import ../../../nixos/dependencies.nix;
let
  globalCfg = config.machines.base;
  cfg = config.services.mail_ui;
in
{
  options.services.mail_ui = {
    enable = lib.mkEnableOption "enable Mail (GMail cleaner) UI server";
    package = lib.mkOption {
      type = lib.types.package;
      description = "The mail_ui package to use";
      default = anixpkgs.mail_ui;
    };
    port = lib.mkOption {
      type = lib.types.port;
      description = "Port to run the server on";
      default = service-ports.mail_ui;
    };
    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain path for reverse proxy";
      default = "/mail";
    };
    gmailBin = lib.mkOption {
      type = lib.types.str;
      description = "Path to the gmail-parser CLI (gmail-manager) used for cleaning runs";
      default = "${anixpkgs.gmail-parser}/bin/gmail-manager";
    };
    rcrsync = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      description = "The rcrsync package to add to the service PATH (for config cloud sync)";
      default = null;
    };
  };

  config = lib.mkIf cfg.enable {
    machines.base.webServices = [
      {
        name = "Mail";
        path = "/mail/";
        description = "GMail cleaner and email archive";
        icon = "envelope";
        faviconSvg = anixpkgs.pkgData.icons.favicons."envelope".data;
      }
    ];

    systemd.services.mail_ui = {
      enable = true;
      description = "Mail (GMail cleaner) UI Web Server";
      unitConfig = {
        StartLimitIntervalSec = 0;
      };
      path = (lib.optional (cfg.rcrsync != null) cfg.rcrsync) ++ [
        "/run/current-system/sw"
      ];
      environment.HOME = globalCfg.homeDir;
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/mail-ui --port ${builtins.toString cfg.port} --subdomain ${cfg.subdomain} --gmail-bin ${cfg.gmailBin}";
        ReadWritePaths = [ "/" ];
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
          proxy_read_timeout 3600;
          proxy_send_timeout 3600;
        '';
      };
    };
  };
}
