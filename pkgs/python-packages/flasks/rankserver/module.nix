{ pkgs, config, lib, ... }:
with pkgs;
with lib;
let cfg = config.services.rankserver;
in {
  options.services.rankserver = with types; {
    enable = mkEnableOption "enable rank server";
    package = mkOption {
      type = types.package;
      description = "The rank server package to use";
      default = pkgs.rankserver;
    };
    homeDir = mkOption {
      type = types.str;
      description = "Home directory (will be cwd of the server)";
      default = "/data/andrew";
    };
    dataDir = mkOption {
      type = types.str;
      description =
        "Data directory with rankable elements (.png|.txt). RELATIVE path from ~.";
      default = "rankables";
    };
    port = mkOption {
      type = types.int;
      description = "Port for the server to use";
      default = 5000;
    };
    openFirewall = mkOption {
      type = types.bool;
      description =
        "Whether to open the specific firewall port for inter-computer usage";
      default = false;
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.port ];
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
