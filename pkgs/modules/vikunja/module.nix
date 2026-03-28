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
  cfg = config.services.vikunja-ats;

  # Package the Vikunja MCP server
  vikunja-mcp-server = pkgs.writeScriptBin "vikunja-mcp-server" ''
    #!${pkgs.python3}/bin/python3
    ${builtins.readFile ./vikunja-mcp-server.py}
  '';
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
    # Use onclick handler to construct URL with current hostname and port
    machines.base.webServices = [
      {
        name = "Vikunja";
        path = "#";
        description = "Task management system (port ${toString service-ports.vikunja.public})";
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
        publicurl: https://${cfg.domain}:${toString service-ports.vikunja.public}

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
          - "*"
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
        VIKUNJA_SERVICE_PUBLICURL = "https://${cfg.domain}:${toString service-ports.vikunja.public}";
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
    # Note: Since we need both HTTP and HTTPS on the same port (3457),
    # we use onlySSL=true to serve only HTTPS on 3457
    services.nginx.virtualHosts."${config.networking.hostName}.local:${toString service-ports.vikunja.public}" =
      {
        onlySSL = true;
        sslCertificateKey = "${globalCfg.homeDir}/secrets/vpn/key.pem";
        sslCertificate = "${globalCfg.homeDir}/secrets/vpn/chain.pem";
        listen = [
          {
            addr = "0.0.0.0";
            port = service-ports.vikunja.public;
            ssl = true;
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

    # Add vikunja and vikunja-mcp-server to system packages
    environment.systemPackages = [
      pkgs.vikunja
      vikunja-mcp-server
    ];
  };
}
