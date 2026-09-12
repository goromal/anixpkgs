{
  pkgs,
  config,
  lib,
  ...
}:
let
  globalCfg = config.machines.base;
  cfg = config.services.plexNode;
  mediaOrganizerConfig = pkgs.writeText "media-organizer.json" (
    builtins.toJSON {
      episode_api = "tvmaze";
      episode_directory = "${cfg.mediaDir}/Shows/{series}/Season {season:02}";
      episode_format = "{series} - S{season:02}E{episode:02} - {title}.{extension}";
      movie_api = "tmdb";
      movie_directory = "${cfg.mediaDir}/Movies/{name} ({year})";
      movie_format = "{name} ({year}).{extension}";
      no_guess = true;
      no_overwrite = true;
      replace_before = {
        ":" = "";
      };
    }
  );
  mediaOrganizer = pkgs.writeShellApplication {
    name = "media-organize";
    runtimeInputs = [ pkgs.mnamer ];
    text = ''
      usage() {
        echo "Usage: media-organize [--apply] [mnamer options] TARGET..."
        echo
        echo "Preview Plex-compatible renames and moves under ${cfg.mediaDir}."
        echo "Pass --apply as the first argument to make the proposed changes."
        echo "Existing destination files are never overwritten."
        echo "Review matches interactively; batch mode can select the wrong title."
        echo "Target loose media: recursive moves do not include NFO or artwork sidecars."
        echo
        echo "Examples:"
        echo "  media-organize --media movie '${cfg.mediaDir}/Movies/Anchorman.mp4'"
        echo "  media-organize --apply --media movie '${cfg.mediaDir}/Movies/Anchorman.mp4'"
        echo "  media-organize --media movie '${cfg.mediaDir}/Movies'"
      }

      mode_args=(--test)
      case "''${1:-}" in
        --apply)
          mode_args=()
          shift
          ;;
        --help|-h|"")
          usage
          exit 0
          ;;
      esac

      if [[ "$#" -eq 0 ]]; then
        usage >&2
        exit 2
      fi

      exec mnamer \
        --config-path ${lib.escapeShellArg mediaOrganizerConfig} \
        --no-overwrite \
        "''${mode_args[@]}" \
        "$@"
    '';
  };
in
{
  options.services.plexNode = {
    enable = lib.mkEnableOption "enable plex node services";
    mediaDir = lib.mkOption {
      type = lib.types.str;
      default = "${globalCfg.homeDir}/media-empire";
      description = "Media library root organized for Plex.";
    };
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
      "d ${cfg.mediaDir} 0755 plex media -"
    ];

    environment.systemPackages = [ mediaOrganizer ];

    # Register Plex in the web services landing page
    machines.base.webServices = [
      {
        name = "Plex";
        tag = "Content";
        path = "#";
        description = "Plex Media Server (port 32400)";
        icon = "film";
      }
    ];

    # Bind-mount media into a path plex can traverse without needing access to
    # the user's home (which stays 0700 as home-manager sets it). Systemd resolves
    # the source as root; plex only ever sees /var/lib/plex-media.
    systemd.services.plex.serviceConfig.BindReadOnlyPaths = [
      "${cfg.mediaDir}:/var/lib/plex-media"
    ];
  };
}
