{
  pkgs,
  lib,
  config,
  ...
}:
with import ../../../nixos/dependencies.nix { system = pkgs.stdenv.hostPlatform.system; };
let
  globalCfg = config.machines.base;
  cfg = config.services.budget_ui;
in
{
  options.services.budget_ui = {
    enable = lib.mkEnableOption "enable budget server";
    rootDir = lib.mkOption {
      type = lib.types.str;
      description = "Root directory for the server";
      default = "${globalCfg.homeDir}/data/budgets";
    };
    package = lib.mkOption {
      type = lib.types.package;
      description = "The budget_ui package to use";
      default = anixpkgs.budget_ui;
    };
    pathPkgs = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      description = "Packages to expose to the program's PATH";
      default = [ ];
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.budget_ui = {
      enable = true;
      description = "Budget UI";
      unitConfig = {
        StartLimitIntervalSec = 0;
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/budget_ui --subdomain /budget --port ${builtins.toString service-ports.budget_ui}";
        ReadWritePaths = [
          "/"
          "${cfg.rootDir}"
          "${globalCfg.homeDir}"
        ];
        WorkingDirectory = cfg.rootDir;
        Restart = "always";
        RestartSec = 5;
        User = "andrew";
        Group = "dev";
      };
      wantedBy = [ "multi-user.target" ];
      path = cfg.pathPkgs;
    };

    machines.base.runWebServer = true;
    services.nginx.virtualHosts."${config.networking.hostName}.local" = {
      locations."/budget/" = {
        proxyPass = "http://127.0.0.1:${builtins.toString service-ports.budget_ui}/budget/";
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
