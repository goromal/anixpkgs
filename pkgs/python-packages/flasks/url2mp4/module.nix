{ pkgs, config, lib, ... }:
let cfg = config.services.url2mp4server;
in {
  options.services.url2mp4server = {
    enable = lib.mkEnableOption "enable smf server";
    package = lib.mkOption {
      type = lib.types.package;
      description = "The smf server package to use";
      default = pkgs.flask-url2mp4;
    };
    rootDir = lib.mkOption {
      type = lib.types.str;
      description = "Root directory for data and configuration";
      default = "/data/andrew/url2mp4server";
    };
    port = lib.mkOption {
      type = lib.types.int;
      description = "Port for the server to use";
      default = 5000;
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules =
      [ "d  ${cfg.rootDir} - andrew dev" "Z  ${cfg.rootDir} - andrew dev" ];
    systemd.services.url2mp4server = {
      enable = true;
      description = "SMF server";
      unitConfig = { StartLimitIntervalSec = 0; };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/flask_url2mp4 --port ${
            builtins.toString cfg.port
          }";
        ReadWritePaths = [ "${cfg.rootDir}" ];
        WorkingDirectory = cfg.rootDir;
        Restart = "always";
        RestartSec = 5;
        User = "andrew";
        Group = "dev";
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}
