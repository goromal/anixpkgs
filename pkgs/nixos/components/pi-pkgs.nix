{
  pkgs,
  config,
  lib,
  ...
}:
with import ../dependencies.nix { system = pkgs.stdenv.hostPlatform.system; };
{
  home.packages = [
    (pkgs.writeShellScriptBin "wifi-connect" ''
      nmcli d wifi connect LANtasia password 2292238177 ifname wlp1s0u1u1
    '')
    (pkgs.writeShellScriptBin "switch-rpi4-configuration" ''
      set -e
      configPath="$1"
      if [[ -z "$configPath" ]]; then
          echo_red "Path to configuration.nix file not provided."
          exit 1
      fi
      echo_yellow "Building and switching to configuration $configPath..."
      export NIXPKGS_ALLOW_UNFREE=1
      sysConfigPath=$(nix-build '<nixpkgs/nixos>' -A config.system.build.toplevel -I nixos-config=$configPath --no-out-link)
      echo "System configuration path: $sysConfigPath"
      echo_yellow "Switching configuration..."
      sudo nix-env -p /nix/var/nix/profiles/system --set "''${sysConfigPath}"
      sudo "''${sysConfigPath}/bin/switch-to-configuration" boot
      echo_yellow "...Done! Reboot for the changes to take effect."
    '')
  ];
}
