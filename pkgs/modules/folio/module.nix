{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
with import ../../nixos/dependencies.nix;
let
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
        ExecStart = "${pkgs.folio-backend}/bin/folio-backend";
        WorkingDirectory = cfg.dataDir;
        Restart = "on-failure";
        RestartSec = "5s";
        UMask = "0027";
        Environment = [
          "FOLIO_DB=${cfg.dataDir}/folio.db"
          "FOLIO_HOST=127.0.0.1"
          "FOLIO_PORT=${toString service-ports.folio.internal}"
        ];

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
      };
    };

    services.folio-mcp.enable = true;
  };
}
