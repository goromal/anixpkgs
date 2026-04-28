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

    # Ensure the media directory has appropriate permissions
    systemd.tmpfiles.rules = [
      "d /data/andrew/media-empire 0755 plex media -"
      "z /data/andrew 0701 andrew dev -"
    ];

    # Register Plex in the web services landing page
    machines.base.webServices = [
      {
        name = "Plex";
        path = "#";
        description = "Plex Media Server (port 32400)";
      }
    ];

    # Grant plex access to media despite ProtectHome sandboxing
    systemd.services.plex.serviceConfig.BindReadOnlyPaths = [
      "/data/andrew/media-empire"
    ];
  };
}
