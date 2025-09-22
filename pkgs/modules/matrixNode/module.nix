{ pkgs, config, lib, ... }:
with import ../../nixos/dependencies.nix;
let
  globalCfg = config.machines.base;
  cfg = config.services.matrixNode;
in {
  options.services.matrixNode = {
    enable = lib.mkEnableOption "enable matrix node services";
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
      settings = {
        server_name = "${config.networking.hostName}.local";
        public_baseurl = "https://matrix.${config.networking.hostName}.local/";
        database.name = "psycopg2";
        database.user = "matrix-synapse";
        registration_shared_secret =
          "${config.networking.hostName}.matrix-synapse";
        listeners = [{
          port = service-ports.matrix;
          bind_addresses = [ "127.0.0.1" ];
          type = "http";
          tls = false;
          resources = [{
            names = [ "client" "federation" ];
            compress = false;
          }];
        }];
      };
    };

    # register_new_matrix_user -k [host].matrix-synapse http://localhost:[port] -u andrew -p [pass] -a
    # register_new_matrix_user -k ats.matrix-synapse http://localhost:[port] -u bot -p [pass]

    machines.base.runWebServer = true;
    services.nginx = {
      enable = true;
      virtualHosts."matrix.${config.networking.hostName}.local" = {
        forceSSL = false;
        locations."/_matrix/" = { proxyPass = "http://127.0.0.1:8008"; };
        locations."/_synapse/" = { proxyPass = "http://127.0.0.1:8008"; };
      };
    };
  };
}
