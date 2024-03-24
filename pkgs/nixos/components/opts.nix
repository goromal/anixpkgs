{ pkgs, config, lib, ... }:
with pkgs;
with import ../dependencies.nix { inherit config; }; {
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
    cloudDirs = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      description =
        "List of {name,cloudname,dirname} attributes defining the syncable directories by rcrsync";
      default = [
        {
          name = "configs";
          cloudname = "dropbox:configs";
          dirname = "$HOME/configs";
        }
        {
          name = "secrets";
          cloudname = "dropbox:secrets";
          dirname = "$HOME/secrets";
        }
        {
          name = "games";
          cloudname = "dropbox:games";
          dirname = "$HOME/games";
        }
        {
          name = "data";
          cloudname = "box:data";
          dirname = "$HOME/data";
        }
        {
          name = "documents";
          cloudname = "drive:Documents";
          dirname = "$HOME/Documents";
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
  };
}
