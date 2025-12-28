{ pkgs, config, lib, ... }:
let
  globalCfg = config.machines.base;
  cfg = config.services.plexNode;
in {
  options.services.plexNode = {
    enable = lib.mkEnableOption "enable plex node services";
  };
  config = lib.mkIf cfg.enable {
    # Hard drive partition mount (lsblk -f)
    fileSystems."/mnt/media-empire" = {
      device = "/dev/disk/by-uuid/40E4C87FE4C878A4";
      fsType = "ntfs-3g";
      options = [ "defaults" "rw" "nofail" "uid=1000" "gid=100" "umask=022" ];
    };

    # Enable Plex Media Server
    services.plex = {
      enable = true;
      openFirewall = true;
      # Default Plex data directory
      dataDir = "/var/lib/plex";
    };

    # Define a 'media' group
    users.groups.media = { };

    # Make sure the Plex user can read media
    users.users.plex.extraGroups = [ "media" ];

    # Ensure the drive has appropriate permissions
    systemd.tmpfiles.rules = [ "d /mnt/media-empire 0755 plex media -" ];
  };
}
