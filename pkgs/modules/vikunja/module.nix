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

    mcp = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable MCP server integration for Claude Code";
      };

      secretsFile = mkOption {
        type = types.str;
        default = "${globalCfg.homeDir}/secrets/vikunja/secrets.json";
        description = "Path to secrets.json file containing token";
      };

      tokenKey = mkOption {
        type = types.str;
        default = "token";
        description = "JSON key name for the API token in secretsFile";
      };

      configFile = mkOption {
        type = types.str;
        default = "${globalCfg.homeDir}/.config/claude-code/mcp-servers.json";
        description = "Path to Claude Code MCP servers configuration file";
      };
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

    # Automatically configure MCP server for Claude Code
    system.activationScripts.vikunja-mcp-config = mkIf cfg.mcp.enable (
      lib.stringAfter [ "users" ] ''
        # Run as the user, not root
        if [ -f "${cfg.mcp.secretsFile}" ]; then
          VIKUNJA_TOKEN=$(${pkgs.jq}/bin/jq -r '.${cfg.mcp.tokenKey} // empty' "${cfg.mcp.secretsFile}" 2>/dev/null || echo "")

          if [ -n "$VIKUNJA_TOKEN" ]; then
            # Create config directory
            mkdir -p "$(dirname "${cfg.mcp.configFile}")"

            # Create or update MCP servers config
            if [ -f "${cfg.mcp.configFile}" ]; then
              # Merge with existing config
              ${pkgs.jq}/bin/jq \
                --arg token "$VIKUNJA_TOKEN" \
                '.mcpServers.vikunja = {
                  "command": "vikunja-mcp-server",
                  "env": {
                    "VIKUNJA_URL": "https://${cfg.domain}:${toString service-ports.vikunja.public}",
                    "VIKUNJA_API_TOKEN": $token
                  }
                }' \
                "${cfg.mcp.configFile}" > "${cfg.mcp.configFile}.tmp"
              mv "${cfg.mcp.configFile}.tmp" "${cfg.mcp.configFile}"
            else
              # Create new config
              cat > "${cfg.mcp.configFile}" <<EOF
        {
          "mcpServers": {
            "vikunja": {
              "command": "vikunja-mcp-server",
              "env": {
                "VIKUNJA_URL": "https://${cfg.domain}:${toString service-ports.vikunja.public}",
                "VIKUNJA_API_TOKEN": "$VIKUNJA_TOKEN"
              }
            }
          }
        }
        EOF
            fi

            # Set proper ownership
            chown andrew:dev "${cfg.mcp.configFile}"
            chmod 600 "${cfg.mcp.configFile}"

            echo "Vikunja MCP configuration updated at ${cfg.mcp.configFile}"
          else
            echo "Warning: '${cfg.mcp.tokenKey}' not found in ${cfg.mcp.secretsFile}"
          fi
        else
          echo "Warning: Secrets file ${cfg.mcp.secretsFile} not found. Skipping MCP configuration."
        fi
      ''
    );
  };
}
