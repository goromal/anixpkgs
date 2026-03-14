{
  pkgs,
  config,
  lib,
  ...
}:
with import ../../../nixos/dependencies.nix;
let
  cfg = config.services.rankserver;
in
{
  options.services.rankserver = {
    enable = lib.mkEnableOption "enable rank server";
    package = lib.mkOption {
      type = lib.types.package;
      description = "The rank server package to use";
      default = pkgs.rankserver;
    };
    rootDir = lib.mkOption {
      type = lib.types.str;
      description = "Home directory (will be cwd of the server)";
      default = "/data/andrew";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [ "d ${cfg.rootDir}/defaultRankables 0755 andrew dev -" ];

    systemd.services.rankserver-setup = {
      description = "Reset rankables symlink to defaultRankables";
      wantedBy = [ "multi-user.target" ];
      before = [ "rankserver.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.coreutils}/bin/ln -sfn ${cfg.rootDir}/defaultRankables ${cfg.rootDir}/rankables";
      };
    };

    systemd.services.rankserver = {
      enable = true;
      description = "Rank server";
      unitConfig = {
        StartLimitIntervalSec = 0;
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/rankserver --port ${builtins.toString service-ports.rankserver} --data-dir ${cfg.rootDir}/rankables --subdomain /rank";
        ReadWritePaths = [ "/" ];
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
      locations."/rank/" = {
        proxyPass = "http://127.0.0.1:${builtins.toString service-ports.rankserver}/rank/";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };
  };
}
