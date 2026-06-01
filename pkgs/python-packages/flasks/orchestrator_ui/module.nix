{
  pkgs,
  lib,
  config,
  ...
}:
with import ../../../nixos/dependencies.nix;
let
  globalCfg = config.machines.base;
  cfg = config.services.orchestrator_ui;
  serviceList = builtins.concatStringsSep "/" (map (x: "${x.name}.service") globalCfg.timedOrchJobs);
in
{
  options.services.orchestrator_ui = {
    enable = lib.mkEnableOption "enable orchestrator UI";
    package = lib.mkOption {
      type = lib.types.package;
      description = "The orchestrator_ui package to use";
      default = anixpkgs.orchestrator_ui;
    };
  };

  config = lib.mkIf cfg.enable {
    machines.base.webServices = [
      {
        name = "Orchestrator";
        path = "/orchestrator/";
        description = "Orchestrator job management";
      }
    ];

    systemd.services.orchestrator_ui = {
      enable = true;
      description = "Orchestrator UI";
      unitConfig = {
        StartLimitIntervalSec = 0;
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/orchestrator_ui --subdomain /orchestrator --port ${builtins.toString service-ports.orchestrator_ui} --orch-port ${builtins.toString service-ports.orchestrator}${
          lib.optionalString (serviceList != "") " --services ${serviceList}"
        }";
        Restart = "always";
        RestartSec = 5;
        User = "root";
        Group = "root";
      };
      wantedBy = [ "multi-user.target" ];
    };

    machines.base.runWebServer = true;
    services.nginx.virtualHosts."${config.networking.hostName}.local" = {
      locations."/orchestrator/" = {
        proxyPass = "http://127.0.0.1:${builtins.toString service-ports.orchestrator_ui}/orchestrator/";
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
