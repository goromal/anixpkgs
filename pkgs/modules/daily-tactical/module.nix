{ pkgs, lib, config, ... }:
with import ../../nixos/dependencies.nix;
let
  globalCfg = config.machines.base;
  cfg = config.services.daily-tactical;
in {
  options.services.daily-tactical = {
    enable = lib.mkEnableOption "enable daily tactical server";
    user = lib.mkOption {
      type = lib.types.str;
      description = "Service owner user";
    };
    group = lib.mkOption {
      type = lib.types.str;
      description = "Service owner group";
    };
    htmlDir = lib.mkOption {
      type = lib.types.str;
      description = "Path to HTML directory";
    };
    htmlFile = lib.mkOption {
      type = lib.types.str;
      description = "Path to daily tactical HTML file";
      default = "index.html";
    };
    package = lib.mkOption {
      type = lib.types.package;
      description =
        "Daily tactical server package";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.htmlDir} - ${cfg.user} ${cfg.group}"
      "Z ${cfg.htmlDir} - ${cfg.user} ${cfg.group}"
    ];

    # ^^^^ TODO service and CLI

    machines.base.runWebServer = true;
    services.nginx.virtualHosts."${config.networking.hostName}.local" = {
      locations."/tactical/" = {
        index = "${cfg.htmlDir}/${cfg.htmlFile}";
      };
    };
  };
}
