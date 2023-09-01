# https://nix.dev/tutorials/installing-nixos-on-a-raspberry-pi
{ config, pkgs, lib, ... }:
with pkgs;
with lib;
let
  hwArch = fetchTarball
    "https://github.com/NixOS/nixos-hardware/archive/c9c1a5294e4ec378882351af1a3462862c61cb96.tar.gz";
in {
  imports = [ "${hwArch}/raspberry-pi/4" ../base.nix ];

  boot.kernelPackages = mkForce linuxPackages_rpi4;

  # Enable GPU acceleration
  hardware.raspberry-pi."4".fkms-3d.enable = true;

  home-manager.users.andrew.home.packages = [
    (writeShellScriptBin "wifi-connect" ''
      nmcli d wifi connect LANtasia password 2292238177 ifname wlp1s0u1u1
    '')
    (writeShellScriptBin "switch-rpi4-configuration" ''
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
