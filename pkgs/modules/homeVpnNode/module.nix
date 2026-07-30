{
  pkgs,
  config,
  lib,
  ...
}:
let
  globalCfg = config.machines.base;
  cfg = config.services.homeVpnNode;

  vpnDir = "${globalCfg.homeDir}/secrets/vpn";
  ovpnFile = "${vpnDir}/client.ovpn";
  authFile = "${vpnDir}/auth.txt";

  homevpn = pkgs.writeShellScriptBin "homevpn" ''
    set -euo pipefail
    ovpn="${ovpnFile}"
    auth="${authFile}"
    unit="home-vpn.service"

    active() { ${pkgs.systemd}/bin/systemctl is-active --quiet "$unit"; }

    preflight() {
      if [ ! -f "$ovpn" ]; then
        echo "error: $ovpn not found — VPN material is not present on this machine." >&2
        exit 1
      fi
      if [ ! -f "$auth" ]; then
        echo "error: $auth not found." >&2
        echo "Create it with two lines (username, then password):" >&2
        echo "  printf '%s\n%s\n' 'YOUR_USER' 'YOUR_PASS' > \"$auth\" && chmod 600 \"$auth\"" >&2
        exit 1
      fi
    }

    show_status() {
      if active; then
        echo "home-vpn: ON"
        ${pkgs.iproute2}/bin/ip -brief addr show tun0 2>/dev/null || true
      else
        echo "home-vpn: off (unit state: $(${pkgs.systemd}/bin/systemctl is-active "$unit" 2>/dev/null || true))"
      fi
    }

    case "''${1:-status}" in
      on)     preflight; ${pkgs.systemd}/bin/systemctl start "$unit"; echo "home-vpn: starting…" ;;
      off)    ${pkgs.systemd}/bin/systemctl stop "$unit"; echo "home-vpn: stopped" ;;
      toggle)
        if active; then
          ${pkgs.systemd}/bin/systemctl stop "$unit"; echo "home-vpn: stopped"
        else
          preflight; ${pkgs.systemd}/bin/systemctl start "$unit"; echo "home-vpn: starting…"
        fi ;;
      status) show_status ;;
      logs)   ${pkgs.systemd}/bin/journalctl -u "$unit" -n "''${2:-50}" --no-pager ;;
      *)      echo "usage: homevpn {on|off|toggle|status|logs}" >&2; exit 2 ;;
    esac
  '';

  homevpnDesktop = pkgs.makeDesktopItem {
    name = "home-vpn-toggle";
    desktopName = "Home VPN (toggle)";
    comment = "Toggle the home OpenVPN tunnel on/off";
    icon = "network-vpn";
    exec = "${homevpn}/bin/homevpn toggle";
    terminal = true;
    categories = [ "Network" ];
  };
in
{
  options.services.homeVpnNode = {
    enable = lib.mkEnableOption "manual home OpenVPN client toggled via the `homevpn` command";
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [ "tun" ];

    environment.systemPackages = [
      pkgs.openvpn
      homevpn
      homevpnDesktop
    ];

    # Manual-only client. NOT in wantedBy → never auto-starts at boot.
    systemd.services.home-vpn = {
      description = "Home OpenVPN client (manual toggle)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      unitConfig = {
        # No material on this machine → unit is skipped (not failed), never errors.
        ConditionPathExists = [ ovpnFile authFile ];
        # Files present but connection fails → cap retries instead of crash-looping.
        StartLimitIntervalSec = 60;
        StartLimitBurst = 4;
      };
      serviceConfig = {
        ExecStart = lib.concatStringsSep " " [
          "${pkgs.openvpn}/bin/openvpn"
          "--suppress-timestamps"
          "--nobind"
          "--auth-nocache"
          "--config ${ovpnFile}"
          "--auth-user-pass ${authFile}"
        ];
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    security.polkit.enable = true;
    security.polkit.extraConfig = ''
      // Allow wheel users to start/stop ONLY home-vpn.service without a password.
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            action.lookup("unit") == "home-vpn.service" &&
            subject.isInGroup("wheel")) {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
