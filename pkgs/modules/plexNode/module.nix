{
  pkgs,
  config,
  lib,
  ...
}:
let
  globalCfg = config.machines.base;
  cfg = config.services.plexNode;
in
{
  options.services.plexNode = {
    enable = lib.mkEnableOption "enable plex node services";
  };
  config = lib.mkIf cfg.enable {
    services.smartd.enable = true;

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

    # Ensure the media directory exists with correct ownership
    systemd.tmpfiles.rules = [
      "d /data/andrew/media-empire 0755 plex media -"
    ];

    # Register Plex in the web services landing page
    machines.base.webServices = [
      {
        name = "Plex";
        path = "#";
        description = "Plex Media Server (port 32400)";
        icon = "film";
      }
    ];

    # Bind-mount media into a path plex can traverse without needing access to
    # /data/andrew (which stays 0700 as home-manager sets it). Systemd resolves
    # the source as root; plex only ever sees /var/lib/plex-media.
    systemd.services.plex.serviceConfig.BindReadOnlyPaths = [
      "/data/andrew/media-empire:/var/lib/plex-media"
    ];
  };
}
