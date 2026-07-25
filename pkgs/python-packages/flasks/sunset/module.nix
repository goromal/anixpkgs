{
  pkgs,
  lib,
  config,
  ...
}:
with import ../../../nixos/dependencies.nix;
let
  cfg = config.services.sunset;
in
{
  options.services.sunset = {
    enable = lib.mkEnableOption "enable the sunset Dolphin status/kill web UI";
    package = lib.mkOption {
      type = lib.types.package;
      description = "The sunset package to use";
      default = anixpkgs.sunset;
    };
    port = lib.mkOption {
      type = lib.types.port;
      description = "Port to run the server on";
      default = service-ports.sunset;
    };
    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain path for reverse proxy";
      default = "/sunset";
    };
  };

  config = lib.mkIf cfg.enable {
    machines.base.webServices = [
      {
        name = "sunset";
        path = "/sunset/";
        description = "Kill the Dolphin emulator";
        icon = "gamepad";
        faviconSvg = anixpkgs.pkgData.icons.favicons."gamepad".data;
      }
    ];

    systemd.services.sunset = {
      description = "sunset Dolphin status/kill Web UI";
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/sunset --port ${builtins.toString cfg.port} --subdomain ${cfg.subdomain}";
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
