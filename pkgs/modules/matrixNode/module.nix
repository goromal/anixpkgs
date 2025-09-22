{ pkgs, config, lib, ... }:
with import ../../nixos/dependencies.nix;
let
  globalCfg = config.machines.base;
  cfg = config.services.matrixNode;
in {
  options.services.matrixNode = {
    enable = lib.mkEnableOption "enable matrix node services";
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      description =
        "Whether to open the specific firewall port for inter-computer usage";
      default = true;
    };
  };
  config = lib.mkIf cfg.enable {
    # Before deploying synapse server, a postgresql database must be set up. For that, please make sure that postgresql is running and the following SQL statements to create a user & database called matrix-synapse were executed before synapse starts up:
    # CREATE ROLE "matrix-synapse";
    # CREATE DATABASE "matrix-synapse" WITH OWNER "matrix-synapse"
    #   TEMPLATE template0
    #   LC_COLLATE = "C"
    #   LC_CTYPE = "C";
    services.postgresql = {
      enable = true;
      ensureDatabases = [ "matrix-synapse" ];
      ensureUsers = [{
        name = "matrix-synapse";
        ensureDBOwnership = true;
      }];
      initialScript = pkgs.writeText "synapse-init.sql" ''
        DROP DATABASE IF EXISTS "matrix-synapse";
        CREATE DATABASE "matrix-synapse"
          WITH OWNER "matrix-synapse"
          TEMPLATE template0
          LC_COLLATE = 'C'
          LC_CTYPE = 'C'
          ENCODING = 'UTF8';
      '';
    };

    environment.systemPackages = [ pkgs.matrix-synapse ];

    services.matrix-synapse = {
      enable = true;
      settings.server_name = config.networking.hostName;
      settings.public_baseurl =
        "http://${config.networking.hostName}.local:8008/";
      settings.database.name = "psycopg2";
      settings.database.user = "matrix-synapse";
      settings.registration_shared_secret =
        "${config.networking.hostName}.matrix-synapse";
    };

    # register_new_matrix_user -k [host].matrix-synapse http://localhost:8008 -u andrew -p [pass] -a
    # register_new_matrix_user -k ats.matrix-synapse http://localhost:8008 -u bot -p [pass]

    networking.firewall.allowedTCPPorts =
      lib.mkIf cfg.openFirewall [ service-ports.matrix ];
  };
}
