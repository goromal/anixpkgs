{
  pkgs,
  lib,
  config,
  ...
}:
with import ../../../nixos/dependencies.nix;
let
  cfg = config.services.anix-upgrade-ui;
  globalCfg = config.machines.base;
in
{
  options.services.anix-upgrade-ui = {
    enable = lib.mkEnableOption "enable anix-upgrade web UI";
    package = lib.mkOption {
      type = lib.types.package;
      description = "The anix-upgrade-ui package to use";
      default = anixpkgs.anix_upgrade_ui;
    };
    anixUpgradeBin = lib.mkOption {
      type = lib.types.str;
      description = "Path to the anix-upgrade binary";
      default = "${anixpkgs.anix-upgrade}/bin/anix-upgrade";
    };
    port = lib.mkOption {
      type = lib.types.port;
      description = "Port to run the server on";
      default = service-ports.anix_upgrade_ui;
    };
    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain path for reverse proxy";
      default = "/anix-upgrade";
    };
  };

  config = lib.mkIf cfg.enable {
    machines.base.webServices = [
      {
        name = "anix-upgrade";
        path = "/anix-upgrade/";
        description = "System upgrade management";
        icon = "arrows-rotate";
        faviconSvg = faviconSvgs."arrows-rotate";
      }
    ];

    systemd.services.anix-upgrade-ui = {
      description = "anix-upgrade Web UI";
      unitConfig.StartLimitIntervalSec = 0;
      path = with pkgs; [
        git
        gawk
        gnused
        "/run/wrappers"
        "/run/current-system/sw"
      ];
      environment.HOME = globalCfg.homeDir;
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/anix-upgrade-ui --port ${builtins.toString cfg.port} --subdomain ${cfg.subdomain} --anix-upgrade-bin ${cfg.anixUpgradeBin}";
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
