{ pkgs, config, lib, ... }:
with import ../../nixos/dependencies.nix;
let cfg = config.services.matrixNode;
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
    services.matrix-synapse = {
      enable = true;
      server_name = "ats";
      settings = {
        listeners = [{
          port = service-ports.matrix;
          bind_addresses = [ "0.0.0.0" "::" ];
          type = "http";
          tls = false; # Only for LAN
          resources = [{
            names = [ "client" "federation" ];
            compress = false;
          }];
        }];
      };
    };

    networking.firewall.allowedTCPPorts =
      lib.mkIf cfg.openFirewall [ service-ports.matrix ];
  };
}
