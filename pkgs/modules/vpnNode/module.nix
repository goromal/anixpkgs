{ pkgs, config, lib, ... }:
with import ../../nixos/dependencies.nix;
let
  globalCfg = config.machines.base;
  cfg = config.services.vpnNode;
in {
  options.services.vpnNode = {
    enable = lib.mkEnableOption "enable VPN node services";
    privateKeyPath = lib.mkOption {
      type = lib.types.str;
      description = "Path to the private key file";
      default = "${globalCfg.homeDir}/secrets/wireguard-keys/private";
    };
    publicKey = lib.mkOption {
      type = lib.types.str;
      description = "Client public key";
      default = "Z9QCnsAEoQtYJgPIMxQYs6r1qx2/YArbRrrT+raljWw=";
    };
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      description =
        "Whether to open the specific firewall port for inter-computer usage";
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.wireguard-tools ];

    # networking.nat = {
    #   enable = true;
    #   externalInterface = globalCfg.wanInterface;
    #   internalInterfaces = [ "wg0" ];
    # };
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedUDPPorts = [ service-ports.wireguard ];
      allowPing = true;
      checkReversePath = false;
      extraCommands = ''
        iptables -t nat -A POSTROUTING -s 10.100.0.0/24 -o ${globalCfg.wanInterface} -j MASQUERADE
      '';
    };

    # # Reflect mDNS through VPN
    # services.avahi.reflector = true;
    # services.avahi.interfaces = [ "wg0" ];

    networking.wireguard = {
      enable = true;
      interfaces = {
        "wg0" = {
          # Determines the IP address and subnet of the server's end of the tunnel interface.
          ips = [ "10.100.0.1/24" ];
          # The port that WireGuard listens to. Must be accessible by the client.
          listenPort = service-ports.wireguard;
          # # This allows the wireguard server to route your traffic to the internet and hence be like a VPN
          # # For this to work you have to set the dnsserver IP of your router (or dnsserver of choice) in your clients
          # postSetup = ''
          #   ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 10.100.0.0/24 -o ${globalCfg.wanInterface} -j MASQUERADE
          # '';
          # # This undoes the above command
          # postShutdown = ''
          #   ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 10.100.0.0/24 -o ${globalCfg.wanInterface} -j MASQUERADE
          # '';
          privateKeyFile = cfg.privateKeyPath;
          peers = [{
            publicKey = cfg.publicKey;
            # List of IPs assigned to this peer within the tunnel subnet. Used to configure routing.
            allowedIPs = [ "10.100.0.2/32" ];
          }];
        };
      };
    };

  };
}
