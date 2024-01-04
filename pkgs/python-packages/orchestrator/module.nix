{ pkgs, config, lib, ... }:
with pkgs;
with lib;
let cfg = config.services.orchestratord;
in {
  options.services.orchestratord = with types; {
    enable = mkEnableOption "enable orchestrator daemon";
    rootDir = mkOption {
      type = types.str;
      description = "Root directory for data and configuration";
      default = "/data/andrew/orchestratord";
    };
    orchestratorPkg = mkOption {
      type = types.package;
      description = "The orchestrator package to use";
    };
    threads = mkOption {
      type = types.int;
      description = "Number of concurrent threads to orchestrate";
      default = 2;
    };
    pathPkgs = mkOption {
      type = types.listOf types.package;
      description = "Packages to expose to orchestratord's PATH";
      default = [ ];
    };
    isNixOS = mkOption {
      type = types.bool;
      description = "Whether this service is running on NixOS";
      default = true;
    };
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules =
      [ "d  ${cfg.rootDir} - andrew dev" "Z  ${cfg.rootDir} - andrew dev" ];
    systemd.services.orchestratord = {
      enable = true;
      description = "Orchestrator daemon";
      unitConfig = { StartLimitIntervalSec = 0; };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.orchestratorPkg}/bin/orchestratord -n ${
            builtins.toString cfg.threads
          }";
        ReadWritePaths = mkIf cfg.isNixOS [ "/" ];
        WorkingDirectory = cfg.rootDir;
        Restart = "always";
        RestartSec = 5;
        User = mkIf cfg.isNixOS "andrew";
        Group = mkIf cfg.isNixOS "dev";
      };
      wantedBy = if cfg.isNixOS then [ "multi-user.target" ] else [ "system-manager.target" ];
      path = cfg.pathPkgs;
    };
  };
}
