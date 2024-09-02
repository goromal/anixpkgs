{ pkgs, config, lib, ... }:
with pkgs;
with import ../dependencies.nix { inherit config; };
let opts = config.mods.opts;
in {
  options.mods.opts = {
    standalone = lib.mkOption {
      type = lib.types.bool;
      description =
        "Whether this is a standalone Nix installation (default: false)";
      default = false;
    };
    homeDir = lib.mkOption {
      type = lib.types.str;
      description =
        "Home directory to put the wallpaper in (default: /data/andrew)";
      default = "/data/andrew";
    };
    homeState = lib.mkOption {
      type = lib.types.str;
      description = "Initiating state of home-manager (example: '22.05')";
    };
    userOrchestrator = lib.mkOption {
      type = lib.types.bool;
      description =
        "Whether to run a user-domain instance of orchestratord (default: true)";
      default = true;
    };
    cloudAutoSync = lib.mkOption {
      type = lib.types.bool;
      description = "Whether to automatically sync cloud dirs (default: true)";
      default = true;
    };
    cloudAutoSyncInterval = lib.mkOption {
      type = lib.types.int;
      description = "Interval (in minutes) of cloud dirs sync (default: 10)";
      default = 10;
    };
    cloudDirs = lib.mkOption { # ^^^^ TODO trace all dependents
      type = lib.types.listOf lib.types.attrs;
      description =
        "List of {name,cloudname,dirname} attributes defining the syncable directories by rcrsync";
      # default = [ # ^^^^ TODO make this build work
      #   {
      #     name = "configs";
      #     cloudname = "dropbox:configs";
      #     dirname = "${opts.homeDir}/configs";
      #     daemonmode = true;
      #   }
      #   {
      #     name = "secrets";
      #     cloudname = "dropbox:secrets";
      #     dirname = "${opts.homeDir}/secrets";
      #     daemonmode = true;
      #   }
      #   {
      #     name = "games";
      #     cloudname = "dropbox:games";
      #     dirname = "${opts.homeDir}/games";
      #     daemonmode = false;
      #   }
      #   {
      #     name = "data";
      #     cloudname = "box:data";
      #     dirname = "${opts.homeDir}/data";
      #     daemonmode = true;
      #   }
      #   {
      #     name = "documents";
      #     cloudname = "drive:Documents";
      #     dirname = "${opts.homeDir}/Documents";
      #     daemonmode = true;
      #   }
      # ];
      default = [
        {
          name = "configs";
          cloudname = "dropbox:configs";
          dirname = "/data/andrew/configs";
          daemonmode = true;
        }
        {
          name = "secrets";
          cloudname = "dropbox:secrets";
          dirname = "/data/andrew/secrets";
          daemonmode = true;
        }
        {
          name = "games";
          cloudname = "dropbox:games";
          dirname = "/data/andrew/games";
          daemonmode = false;
        }
        {
          name = "data";
          cloudname = "box:data";
          dirname = "/data/andrew/data";
          daemonmode = true;
        }
        {
          name = "documents";
          cloudname = "drive:Documents";
          dirname = "/data/andrew/Documents";
          daemonmode = true;
        }
      ];
    };
    editor = lib.mkOption {
      type = lib.types.str;
      description = "Code editor (executable) of choice";
      default = "codium";
    };
    browserExec = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      description = "Executable name to open your browser of choice";
      default = null;
    };
    screenResolution = lib.mkOption {
      type = lib.types.str;
      description = "Screen resolution in [width]x[height] format";
      default = "1920x1080";
    };
  };
}
