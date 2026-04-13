{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
with import ../../nixos/dependencies.nix;
let
  globalCfg = config.machines.base;
  cfg = config.services.ladder-ats;

  ruleset = pkgs.writeText "ladder-ruleset.yaml" ''
    - domains:
        - www.nytimes.com
        - www.time.com
      useFlareSolverr: true
      headers:
        user-agent: Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)
        cookie: nyt-a=; nyt-gdpr=0; nyt-geo=DE; nyt-privacy=1
        referer: https://www.google.com/
        content-security-policy: "default-src * 'unsafe-inline' 'unsafe-eval' data: blob:;"
      injections:
        - position: head
          append: |
            <script>
              window.localStorage.clear();
              document.addEventListener("DOMContentLoaded", () => {
                const banners = document.querySelectorAll('div[data-testid="inline-message"], div[id^="ad-"], div[id^="leaderboard-"], div.expanded-dock, div.pz-ad-box, div[id="top-wrapper"], div[id="bottom-wrapper"]');
                banners.forEach(el => { el.remove(); });
              });
            </script>
  '';
in
{
  options.services.ladder-ats = {
    enable = mkEnableOption "Ladder paywall-bypass proxy for ATS";

    domain = mkOption {
      type = types.str;
      default = "localhost";
      description = "Domain name for Ladder";
    };
  };

  config = mkIf cfg.enable {
    # Register in the web services landing page (port-based onclick handler)
    machines.base.webServices = [
      {
        name = "Ladder";
        path = "#";
        description = "Paywall bypass proxy (port ${toString service-ports.ladder.public})";
      }
    ];

    networking.firewall.allowedTCPPorts = [ service-ports.ladder.public ];

    machines.base.runWebServer = true;

    # FlareSolverr sidecar — handles Cloudflare/JS challenges for ladder
    systemd.services.flaresolverr = {
      description = "FlareSolverr";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        HOST = "127.0.0.1";
        PORT = toString service-ports.flaresolverr;
        LOG_LEVEL = "info";
        HOME = "/var/lib/flaresolverr";
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.flaresolverr}/bin/flaresolverr";
        Restart = "on-failure";
        RestartSec = "5s";
        DynamicUser = true;
        StateDirectory = "flaresolverr";
        WorkingDirectory = "/var/lib/flaresolverr";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
      };
    };

    # Ladder service
    systemd.services.ladder = {
      description = "Ladder paywall-bypass proxy";
      after = [
        "network.target"
        "flaresolverr.service"
      ];
      wants = [ "flaresolverr.service" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        PORT = toString service-ports.ladder.internal;
        RULESET = "${ruleset}";
        FLARESOLVERR_HOST = "http://127.0.0.1:${toString service-ports.flaresolverr}";
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${anixpkgs.ladder}/bin/ladder";
        Restart = "on-failure";
        RestartSec = "5s";
        DynamicUser = true;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
      };
    };

    # Dedicated nginx virtual host on the public port
    services.nginx.virtualHosts."${config.networking.hostName}.local:${toString service-ports.ladder.public}" = {
      onlySSL = true;
      extraConfig = "merge_slashes off;";
      sslCertificateKey = "${globalCfg.homeDir}/secrets/vpn/key.pem";
      sslCertificate = "${globalCfg.homeDir}/secrets/vpn/chain.pem";
      listen = [
        {
          addr = "0.0.0.0";
          port = service-ports.ladder.public;
          ssl = true;
        }
      ];
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString service-ports.ladder.internal}/";
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
