# Shared machine-specific command packages used by feature modules.
{
  config,
  pkgs,
  lib,
}:
with import ./dependencies.nix;
let
  cfg = config.machines.base;
  atsudo = pkgs.writeShellScriptBin "atsudo" ''
    args=""
    for word in "$@"; do
      args+="$word "
    done
    args=''${args% }
    pw=$(${anixpkgs.sread}/bin/sread ${cfg.homeDir}/secrets/${config.networking.hostName}/p.txt.tyz)
    if [[ ! -z "$pw" ]]; then
      echo "$pw" | sudo -S $args
    else
      sudo $args
    fi
  '';
  machine-rcrsync = anixpkgs.rcrsync.override {
    homeDir = cfg.homeDir;
    cloudDirs = cfg.cloudDirs;
    rcloneCfg = "${cfg.homeDir}/.config/rclone/rclone.conf";
  };
  machine-authm = anixpkgs.authm.override { rcrsync = machine-rcrsync; };
in
{
  inherit atsudo machine-rcrsync machine-authm;
}
