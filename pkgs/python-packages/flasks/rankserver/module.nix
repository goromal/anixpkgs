{ pkgs, config, lib, ... }:
let cfg = config.services.rankserver;
in {
  options.services.rankserver = {
    enable = lib.mkEnableOption "enable rank server";
    package = lib.mkOption {
      type = lib.types.package;
      description = "The rank server package to use";
      default = pkgs.rankserver;
    };
    homeDir = lib.mkOption {
      type = lib.types.str;
      description = "Home directory (will be cwd of the server)";
      default = "/data/andrew";
    };
    dataDir = lib.mkOption {
      type = lib.types.str;
      description =
        "Data directory with rankable elements (.png|.txt). RELATIVE path from ~.";
      default = "rankables";
    };
    port = lib.mkOption {
      type = lib.types.int;
      description = "Port for the server to use";
      default = 5000;
    };
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      description =
        "Whether to open the specific firewall port for inter-computer usage";
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
    systemd.services.rankserver = {
      enable = true;
      description = "Rank server";
      unitConfig = { StartLimitIntervalSec = 0; };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/rankserver --port ${
            builtins.toString cfg.port
          } --data-dir ${cfg.dataDir}";
        ReadWritePaths = [ "${cfg.dataDir}" ];
        WorkingDirectory = cfg.homeDir;
        Restart = "always";
        RestartSec = 5;
        User = "andrew";
        Group = "dev";
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}
