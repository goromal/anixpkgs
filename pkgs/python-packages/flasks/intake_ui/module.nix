{
  pkgs,
  config,
  lib,
  ...
}:
with import ../../../nixos/dependencies.nix;
let
  globalCfg = config.machines.base;
  cfg = config.services.intake_ui;
in
{
  options.services.intake_ui = {
    enable = lib.mkEnableOption "enable intake UI server";
    package = lib.mkOption {
      type = lib.types.package;
      description = "The intake_ui package to use";
      default = anixpkgs.intake_ui;
    };
    port = lib.mkOption {
      type = lib.types.port;
      description = "Port to run the server on";
      default = service-ports.intake_ui;
    };
    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain path for reverse proxy";
      default = "/intake";
    };
    maildir = lib.mkOption {
      type = lib.types.str;
      description = "Path to the goromail Maildir";
      default = "/var/mail/goromail";
    };
  };

  config = lib.mkIf cfg.enable {
    machines.base.webServices = [
      {
        name = "Intake";
        path = "/intake/";
        description = "Send goromail messages";
      }
    ];

    systemd.services.intake_ui = {
      enable = true;
      description = "Intake UI Web Server";
      unitConfig = {
        StartLimitIntervalSec = 0;
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/intake_ui --port ${builtins.toString cfg.port} --subdomain ${cfg.subdomain} --maildir ${cfg.maildir}";
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
        '';
      };
    };
  };
}
