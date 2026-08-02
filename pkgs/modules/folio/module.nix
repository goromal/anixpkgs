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
  cfg = config.services.folio-backend;
in
{
  options.services.folio-backend = {
    enable = mkEnableOption "folio Book Study Companion backend";

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/folio";
      description = "Directory holding the folio SQLite database.";
    };

    desktop = mkEnableOption "folio Electron desktop shell + Gnome launcher";
  };

  config = mkIf cfg.enable {
    users.users.folio = {
      isSystemUser = true;
      group = "folio";
      home = cfg.dataDir;
      createHome = true;
    };
    users.groups.folio = { };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 folio folio -"
      "z ${cfg.dataDir}/folio.db 0640 folio folio -"
    ];

    systemd.services.folio-backend = {
      description = "folio backend (FastAPI)";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = "folio";
        Group = "folio";
        ExecStart = "${anixpkgs.folio-backend}/bin/folio-backend";
        WorkingDirectory = cfg.dataDir;
        Restart = "on-failure";
        RestartSec = "5s";
        UMask = "0027";
        Environment = [
          "FOLIO_DB=${cfg.dataDir}/folio.db"
          "FOLIO_HOST=127.0.0.1"
          "FOLIO_PORT=${toString service-ports.folio.internal}"
          "FOLIO_STATIC_DIR=${anixpkgs.folio-frontend}"
        ];

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
      };
    };

    # ---- web: nginx serves folio (SPA at /folio + API) on the dedicated public
    # port; the backend itself binds localhost only. Mirrors the vikunja pattern. ----
    machines.base.runWebServer = true;
    services.nginx.virtualHosts."${config.networking.hostName}.local:${toString service-ports.folio.public}" =
      {
        onlySSL = true;
        sslCertificateKey = "${globalCfg.homeDir}/secrets/vpn/key.pem";
        sslCertificate = "${globalCfg.homeDir}/secrets/vpn/chain.pem";
        listen = [
          {
            addr = "0.0.0.0";
            port = service-ports.folio.public;
            ssl = true;
          }
        ];
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString service-ports.folio.internal}";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
        # SSE (agent view-follow F + live sync G) must not be buffered.
        locations."/view/stream" = {
          proxyPass = "http://127.0.0.1:${toString service-ports.folio.internal}";
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_buffering off;
            proxy_cache off;
            proxy_read_timeout 3600s;
          '';
        };
      };
    # Landing-page entry (https://<host>.local/). folio's SPA lives at /folio (not
    # the port root), so use an explicit path rather than the "#"+port pattern.
    machines.base.webServices = [
      {
        name = "folio";
        path = "https://${config.networking.hostName}.local:${toString service-ports.folio.public}/folio";
        description = "Book Study Companion";
        icon = "book-open";
      }
    ];

    networking.firewall.allowedTCPPorts = [ service-ports.folio.public ];

    environment.systemPackages = mkIf cfg.desktop [ anixpkgs.folio-desktop ];

    services.folio-mcp.enable = true;
  };
}
