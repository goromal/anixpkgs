{ pkgs, config, lib, ... }:
with import ../dependencies.nix; {
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
    cloudDirs = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      description =
        "List of {name,cloudname,dirname} attributes (dirname is relative to home) defining the syncable directories by rcrsync";
    };
    editor = lib.mkOption {
      type = lib.types.str;
      description = "Code editor (executable) of choice";
      default = "code";
    };
    browserExec = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      description = "Executable name to open your browser of choice";
      default = null;
    };
    wallpaperImage = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      description = "Path to desired wallpaper (for graphical distributions)";
      default = null;
    };
    screenResolution = lib.mkOption {
      type = lib.types.str;
      description = "Screen resolution in [width]x[height] format";
      default = "1920x1080";
    };
    enableMetrics = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to export OS metrics";
    };
  };
}
