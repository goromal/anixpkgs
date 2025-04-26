{ pkgs, lib, config, ... }:
with import ../../../nixos/dependencies.nix;
let
  globalCfg = config.machines.base;
  cfg = config.services.authui;
in {
  options.services.authui = {
    enable = lib.mkEnableOption "enable remote auth server";
    rootDir = {
      type = lib.types.str;
      description = "Root directory for the server";
      default = "${globalCfg.homeDir}/authui";
    };
    package = lib.mkOption {
      type = lib.types.package;
      description = "The authui package to use";
      default = pkgs.authui;
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules =
      [ "d ${cfg.rootDir} - andrew dev" "Z ${cfg.rootDir} - andrew dev" ];

    systemd.services.authui = {
      enable = true;
      description = "Remote auth UI";
      unitConfig = { StartLimitIntervalSec = 0; };
      serviceConfig = {
        Type = "simple";
        ExecStart =
          "${cfg.package}/bin/authui --port ${service-ports.authui} --memory-file ${cfg.rootDir}/refresh_times.json";
        ReadWritePaths = [ "${cfg.rootDir}" "${globalCfg.homeDir}" ];
        WorkingDirectory = cfg.rootDir;
        Restart = "always";
        RestartSec = 5;
        User = "andrew";
        Group = "dev";
      };
      wantedBy = [ "multi-user.target" ];
    };

    machines.base.runWebServer = true;
    services.nginx.virtualHosts."${config.networking.hostName}.local" = {
      locations."/auth/" = {
        proxyPass =
          "http://127.0.0.1:${builtins.toString service-ports.authui}/";
      };
    };
  };
}
