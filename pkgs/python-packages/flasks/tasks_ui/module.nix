{
  pkgs,
  config,
  lib,
  ...
}:
with import ../../../nixos/dependencies.nix;
let
  globalCfg = config.machines.base;
  cfg = config.services.tasks_ui;
in
{
  options.services.tasks_ui = {
    enable = lib.mkEnableOption "enable tasks UI server";
    package = lib.mkOption {
      type = lib.types.package;
      description = "The tasks_ui package to use";
      default = anixpkgs.tasks_ui;
    };
    port = lib.mkOption {
      type = lib.types.port;
      description = "Port to run the server on";
      default = service-ports.tasks_ui;
    };
    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain path for reverse proxy";
      default = "/tasks";
    };
    rcrsync = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      description = "The rcrsync package to add to the service PATH";
      default = null;
    };
  };

  config = lib.mkIf cfg.enable {
    machines.base.webServices = [
      {
        name = "Tasks";
        path = "/tasks/";
        description = "Task management";
      }
    ];

    systemd.services.tasks_ui = {
      enable = true;
      description = "Tasks UI Web Server";
      unitConfig = {
        StartLimitIntervalSec = 0;
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/tasks_ui --port ${builtins.toString cfg.port} --subdomain ${cfg.subdomain}";
        Environment = lib.mkIf (
          cfg.rcrsync != null
        ) "PATH=${cfg.rcrsync}/bin:/run/current-system/sw/bin:/usr/bin";
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
