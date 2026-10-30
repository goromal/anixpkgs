{
  pkgs,
  lib,
  config,
  ...
}:
with import ../../../nixos/dependencies.nix;
let
  globalCfg = config.machines.base;
  cfg = config.services.rcrsync_ui;
  uiConfig = pkgs.writeText "rcrsync-ui.json" (
    builtins.toJSON {
      home_dir = globalCfg.homeDir;
      dirs = map (d: { inherit (d) name cloudname dirname; }) globalCfg.cloudDirs;
    }
  );
in
{
  options.services.rcrsync_ui = {
    enable = lib.mkEnableOption "enable the rcrsync web UI";
    package = lib.mkOption {
      type = lib.types.package;
      description = "The rcrsync_ui package to use";
      default = anixpkgs.rcrsync_ui;
    };
    rcrsync = lib.mkOption {
      type = lib.types.package;
      description = "The machine-configured rcrsync package the UI runs";
    };
    port = lib.mkOption {
      type = lib.types.port;
      description = "Port to run the server on";
      default = service-ports.rcrsync_ui;
    };
    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain path for reverse proxy";
      default = "/rcrsync";
    };
  };

  config = lib.mkIf cfg.enable {
    machines.base.webServices = [
      {
        name = "RCRSync UI";
        tag = "Utilities";
        path = "${cfg.subdomain}/";
        description = "Push, pull and sync cloud directories";
        icon = "arrows-rotate";
        faviconSvg = anixpkgs.pkgData.icons.favicons."arrows-rotate".data;
      }
    ];

    systemd.services.rcrsync_ui = {
      description = "rcrsync Web UI";
      unitConfig = {
        StartLimitIntervalSec = 0;
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/rcrsync_ui --port ${builtins.toString cfg.port} --subdomain ${cfg.subdomain} --config ${uiConfig} --rcrsync ${cfg.rcrsync}/bin/rcrsync";
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
