{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
with import ../../nixos/dependencies.nix;
let
  cfg = config.services.vikunja-ats;
in
{
  options.services.vikunja-ats = {
    enable = mkEnableOption "Vikunja task management for ATS";

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/vikunja";
      description = "Directory where Vikunja stores its data";
    };

    domain = mkOption {
      type = types.str;
      default = "localhost";
      description = "Domain name for Vikunja";
    };
  };

  config = mkIf cfg.enable {
    # Register Vikunja in the web services landing page
    # Use JavaScript to construct URL with current hostname and port
    machines.base.webServices = [
      {
        name = "Vikunja";
        path = "javascript:window.location.href=window.location.protocol+'//'+window.location.hostname+':${toString service-ports.vikunja.public}+'/'";
        description = "Task management system";
      }
    ];

    # Open firewall port for Vikunja web access
    networking.firewall.allowedTCPPorts = [ service-ports.vikunja.public ];

    # Create the vikunja user
    users.users.vikunja = {
      isSystemUser = true;
      group = "vikunja";
      home = cfg.dataDir;
      createHome = true;
    };

    users.groups.vikunja = { };

    # Vikunja configuration file
    environment.etc."vikunja/config.yml".text = ''
      service:
        interface: :${toString service-ports.vikunja.internal}
        enableregistration: true
        enablecaldav: true
        enablelinksharing: true
        enabletaskattachments: true
        enabletaskcomments: true
        enableemailreminders: false
        maxitemsperpage: 100
        publicurl: http://${cfg.domain}:${toString service-ports.vikunja.public}

      database:
        type: sqlite
        path: ${cfg.dataDir}/vikunja.db

      files:
        basepath: ${cfg.dataDir}/files

      auth:
        local:
          enabled: true
        openid:
          enabled: false

      log:
        enabled: true
        path: ${cfg.dataDir}/logs
        level: INFO
        database: off
        databaselevel: WARNING
        events: stdout
        eventslevel: INFO

      cors:
        enable: true
        origins:
          - http://${cfg.domain}:${toString service-ports.vikunja.public}
          - https://${cfg.domain}:${toString service-ports.vikunja.public}
        maxage: 0

      ratelimit:
        enabled: false

      cache:
        enabled: false
    '';

    # Vikunja service (serves both API and frontend)
    systemd.services.vikunja = {
      description = "Vikunja Server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        VIKUNJA_SERVICE_PUBLICURL = "http://${cfg.domain}:${toString service-ports.vikunja.public}";
      };

      serviceConfig = {
        Type = "simple";
        User = "vikunja";
        Group = "vikunja";
        ExecStart = "${pkgs.vikunja}/bin/vikunja";
        WorkingDirectory = cfg.dataDir;
        Restart = "on-failure";
        RestartSec = "5s";

        # Hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
      };

      preStart = ''
        mkdir -p ${cfg.dataDir}/files
        mkdir -p ${cfg.dataDir}/logs
        chown -R vikunja:vikunja ${cfg.dataDir}
      '';
    };

    # Configure nginx reverse proxy
    # Vikunja's nixpkgs frontend is built with /vikunja/ as the API path
    # So we serve both the frontend on :3457 and proxy /vikunja/ on port 80
    machines.base.runWebServer = true;

    # Serve frontend on dedicated port (separate virtualHost)
    services.nginx.virtualHosts."${config.networking.hostName}.local:${toString service-ports.vikunja.public}" =
      {
        listen = [
          {
            addr = "0.0.0.0";
            port = service-ports.vikunja.public;
          }
        ];
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString service-ports.vikunja.internal}/";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
          '';
        };
      };

    # Also proxy /vikunja/ on default port 80 for API access from frontend
    services.nginx.virtualHosts."${config.networking.hostName}.local" = {
      locations."/vikunja/" = {
        proxyPass = "http://127.0.0.1:${toString service-ports.vikunja.internal}/";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Host $host;
        '';
      };
    };

    # Add vikunja-cli and vikunja-mcp-server to system packages
    environment.systemPackages = [
      pkgs.vikunja
      (pkgs.writeScriptBin "vikunja-cli" (builtins.readFile ./vikunja-cli.sh))
      (pkgs.writers.writePython3Bin "vikunja-mcp-server" {
        libraries = [ pkgs.python3Packages.requests ];
      } (builtins.readFile ./vikunja-mcp-server.py))
    ];
  };
}
