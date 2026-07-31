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
      state)
        if [ ! -f "$ovpn" ] || [ ! -f "$auth" ]; then echo "unconfigured"; exit 0; fi
        if active; then
          ip=$(${pkgs.iproute2}/bin/ip -4 -o addr show tun0 2>/dev/null \
               | ${pkgs.gawk}/bin/awk '{split($4,a,"/"); print a[1]; exit}')
          if [ -n "$ip" ]; then echo "connected $ip"; else echo "connecting"; fi
        else
          last=$(${pkgs.systemd}/bin/journalctl -u "$unit" -o cat -n 40 2>/dev/null \
                 | ${pkgs.gnugrep}/bin/grep -aE 'AUTH_FAILED|Initialization Sequence Completed|Started ' \
                 | tail -n1)
          case "$last" in
            *AUTH_FAILED*) echo "auth-failed" ;;
            *)             echo "off" ;;
          esac
        fi ;;
      *)      echo "usage: homevpn {on|off|toggle|status|state|logs}" >&2; exit 2 ;;
    esac
  '';

  pyEnv = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);

  homevpnGui = pkgs.stdenv.mkDerivation {
    pname = "homevpn-gui";
    version = "0.1.0";
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    nativeBuildInputs = [
      pkgs.wrapGAppsHook4
      pkgs.gobject-introspection
    ];
    buildInputs = [
      pyEnv
      pkgs.gtk4
      pkgs.libadwaita
    ];
    installPhase = ''
      runHook preInstall
      install -Dm755 ${./homevpn_gui.py} $out/bin/homevpn-gui
      substituteInPlace $out/bin/homevpn-gui \
        --replace '#!/usr/bin/env python3' '#!${pyEnv}/bin/python3' \
        --replace '@homevpn@' '${homevpn}/bin/homevpn'
      runHook postInstall
    '';
  };

  homevpnGuiDesktop = pkgs.makeDesktopItem {
    name = "homevpn-gui";
    desktopName = "Home VPN";
    comment = "Toggle the home OpenVPN tunnel";
    icon = "network-vpn";
    exec = "${homevpnGui}/bin/homevpn-gui";
    terminal = false;
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
    ]
    ++ lib.optionals globalCfg.graphical [
      homevpnGui
      homevpnGuiDesktop
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
