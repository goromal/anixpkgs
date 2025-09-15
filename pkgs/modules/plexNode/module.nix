{ pkgs, config, lib, ... }:
let
  globalCfg = config.machines.base;
  cfg = config.services.plexNode;
in {
  options.services.plexNode = {
    enable = lib.mkEnableOption "enable plex node services";
  };
  config = lib.mkIf cfg.enable {
    fileSystems."/mnt/media-empire" = {
      device = "/dev/disk/by-uuid/40E4C87FE4C878A4";
      fsType = "ntfs-3g";
      options = [ "defaults" "nofail" "uid=1000" "gid=100" "umask=022" ]; 
    };
  };
}
