{
  pkgs,
  config,
  lib,
  ...
}:
with import ../../../nixos/dependencies.nix;
let
  cfg = config.services.stampserver;
in
{
  options.services.stampserver = {
    enable = lib.mkEnableOption "enable stamp server";
    package = lib.mkOption {
      type = lib.types.package;
      description = "The stamp server package to use";
      default = pkgs.stampserver;
    };
    rootDir = lib.mkOption {
      type = lib.types.str;
      description = "Home directory (will be cwd of the server)";
      default = "/data/andrew";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.rootDir}                   - andrew dev"
      "d ${cfg.rootDir}/defaultStampables - andrew dev"
    ];

    systemd.services.stampserver-setup = {
      description = "Reset stampables symlink to defaultStampables";
      wantedBy = [ "multi-user.target" ];
      before = [ "stampserver.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.coreutils}/bin/ln -sfn ${cfg.rootDir}/defaultStampables ${cfg.rootDir}/stampables";
      };
    };

    systemd.services.stampserver = {
      enable = true;
      description = "Stamp server";
      unitConfig = {
        StartLimitIntervalSec = 0;
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/stampserver --port ${builtins.toString service-ports.stampserver} --data-dir ${cfg.rootDir}/stampables --subdomain /stamp";
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
      locations."/stamp/" = {
        proxyPass = "http://127.0.0.1:${builtins.toString service-ports.stampserver}/stamp/";
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
