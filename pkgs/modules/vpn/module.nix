{ pkgs, config, lib, ... }:
with import ../../nixos/dependencies.nix;
let
  globalCfg = config.machines.base;
  cfg = config.services.vpnNode;
in {
  options.services.vpnNode = {
    enable = lib.mkEnableOption "enable VPN node services";
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      description =
        "Whether to open the specific firewall port for inter-computer usage";
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
        pkgs.wireguard-tools
    ];
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [
      # TODO
    ];

 };
}
