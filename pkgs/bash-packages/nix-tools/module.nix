{ pkgs, config, lib, ... }:
with pkgs;
with import ../dependencies.nix { inherit config; };
let cfg = config.programs.anix-tools;
in {
  options.programs.anix-tools = {
    enable = lib.mkOption {
      type = lib.types.bool;
      description = "Whether to enable the anix-tools suite";
      default = false;
    };
    anixpkgs = lib.mkOption {
      type = lib.types.attrs;
      description = "anixpkgs version to grab the tools from";
      default = null;
    };
    browser-aliases = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      description = "Browser aliases package to use for graphical distros";
      default = null;
    };
    standalone = lib.mkOption {
      type = lib.types.bool;
      description =
        "Whether the containing closure is a standalone Nix install";
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with cfg; [
      anixpkgs.anix-version
      # Only commandeer the browser if we're on NixOS
      (anixpkgs.anix-upgrade.override {
        standalone = cfg.standalone;
        browser-aliases = if cfg.standalone then null else cfg.browser-aliases;
      })
    ];
  };
}
