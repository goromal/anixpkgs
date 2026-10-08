{
  pkgs,
  lib,
  config,
  ...
}:
with import ../../../nixos/dependencies.nix;
let
  cfg = config.services.nexus-ui;
  globalCfg = config.machines.base;
  upgradeCfg = config.services.anix-upgrade-ui;
in
{
  options.services.nexus-ui = {
    advertise = lib.mkEnableOption "advertising this machine to Nexus hubs over mDNS";
    enable = lib.mkEnableOption "the Nexus LAN hub web UI";
    package = lib.mkOption {
      type = lib.types.package;
      description = "The nexus package to use";
      default = anixpkgs.nexus_ui;
    };
    port = lib.mkOption {
      type = lib.types.port;
      description = "Port to run the server on";
      default = service-ports.nexus_ui;
    };
    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain path for reverse proxy";
      default = "/nexus";
    };
    hubHost = lib.mkOption {
      type = lib.types.str;
      description = "Hub hostname that an advertising machine's landing page links to";
      default = "ats.local";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.advertise {
      # The advertised home page is this machine's landing page.
      machines.base.runWebServer = true;
      # The hub links to its own Nexus relatively so it works however it is reached.
      machines.base.nexusUrl =
        if cfg.enable then "${cfg.subdomain}/" else "http://${cfg.hubHost}${cfg.subdomain}/";
      services.avahi.publish.userServices = true;
      services.avahi.extraServiceFiles.anix-nexus = ''
        <?xml version="1.0" standalone="no"?>
        <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
        <service-group>
          <name replace-wildcards="yes">%h</name>
          <service>
            <type>_anix-nexus._tcp</type>
            <port>${toString globalCfg.webServerInsecurePort}</port>
            <txt-record>home=/</txt-record>
            ${lib.optionalString upgradeCfg.enable "<txt-record>upgrade=${upgradeCfg.subdomain}/</txt-record>"}
          </service>
        </service-group>
      '';
    })

    (lib.mkIf cfg.enable {
      machines.base.webServices = [
        {
          name = "Nexus";
          tag = "Utilities";
          path = "${cfg.subdomain}/";
          description = "LAN machine hub and bulk upgrades";
          icon = "network-wired";
          faviconSvg = anixpkgs.pkgData.icons.favicons."network-wired".data;
        }
      ];

      systemd.services.nexus-ui = {
        description = "Nexus LAN hub web UI";
        unitConfig.StartLimitIntervalSec = 0;
        environment.HOME = globalCfg.homeDir;
        serviceConfig = {
          Type = "simple";
          ExecStart = "${cfg.package}/bin/nexus-ui --port ${builtins.toString cfg.port} --subdomain ${cfg.subdomain} --avahi-browse-bin ${pkgs.avahi}/bin/avahi-browse";
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
            proxy_buffering off;
            proxy_read_timeout 3600;
            proxy_send_timeout 3600;
          '';
        };
      };
    })
  ];
}
