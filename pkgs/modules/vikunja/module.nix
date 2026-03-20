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
    # Open firewall port for Vikunja web access
    networking.firewall.allowedTCPPorts = [ 3457 ];

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
        interface: :${toString service-ports.vikunja}
        frontendurl: http://${cfg.domain}:3457
        enableregistration: false
        enablecaldav: true
        enablelinksharing: true
        enabletaskattachments: true
        enabletaskcomments: true
        enableemailreminders: false
        maxitemsperpage: 100
        publicurl: http://${cfg.domain}:3457

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
          - http://${cfg.domain}
          - https://${cfg.domain}
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
    # Vikunja doesn't properly support subpath deployment, so we expose it on a separate port
    # Users access it at http://ats.local:3457 (nginx proxies to internal :3456)
    machines.base.runWebServer = true;
    services.nginx.virtualHosts."${config.networking.hostName}.local" = {
      listen = [
        {
          addr = "0.0.0.0";
          port = 3457;
        }
      ];
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString service-ports.vikunja}/";
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
