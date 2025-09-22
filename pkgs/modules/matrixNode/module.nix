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
    #
    # CREATE ROLE "matrix-synapse";
    # CREATE DATABASE "matrix-synapse" WITH OWNER "matrix-synapse"
    #   TEMPLATE template0
    #   LC_COLLATE = "C"
    #   LC_CTYPE = "C";
    services.postgresql = {
      enable = true;
      # package = pkgs.postgresql_15; # or pkgs.postgresql_16 if you want the newest
      ensureDatabases = [ "matrix-synapse" ];
      ensureUsers = [{
        name = "matrix-synapse";
        ensureDBOwnership = true;
      }];
    };

    services.matrix-synapse = {
      enable = true;
      settings.server_name = config.networking.hostName;
      settings.public_baseurl = "http://${config.networking.hostName}.local:8008/";
      database_type = "psycopg2";
      database_config = {
        name = "matrix-synapse";
        user = "matrix-synapse";
        password = ""; # if you want password auth, set it via a secret
        host = "/run/postgresql"; # unix socket path
      };
    };

    networking.firewall.allowedTCPPorts =
      lib.mkIf cfg.openFirewall [ service-ports.matrix ];
  };
}
