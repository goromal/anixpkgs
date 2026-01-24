{ pkgs, lib, config, ... }:
with import ../../../nixos/dependencies.nix;
let
  globalCfg = config.machines.base;
  cfg = config.services.authui;
  nullScript = pkgs.writeShellScriptBin "null-script" ''
    echo ""
  '';
in {
  options.services.authui = {
    enable = lib.mkEnableOption "enable remote auth server";
    rootDir = lib.mkOption {
      type = lib.types.str;
      description = "Root directory for the server";
      default = "${globalCfg.homeDir}/authui";
    };
    package = lib.mkOption {
      type = lib.types.package;
      description = "The authui package to use";
      default = anixpkgs.authui;
    };
    initScript = lib.mkOption {
      type = lib.types.str;
      description = "The authui init script to use";
      default = "${nullScript}/bin/null-script";
    };
    resetScript = lib.mkOption {
      type = lib.types.str;
      description = "The authui reset script to use";
      default = "${nullScript}/bin/null-script";
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
        ExecStart = "${cfg.package}/bin/authui --subdomain /auth --port ${
            builtins.toString service-ports.authui
          } --memory-file ${cfg.rootDir}/refresh_times.json --init-script ${cfg.initScript} --reset-script ${cfg.resetScript}";
        ReadWritePaths = [ "/" "${cfg.rootDir}" "${globalCfg.homeDir}" ];
        WorkingDirectory = cfg.rootDir;
        Restart = "always";
        RestartSec = 5;
        User = "root";
        Group = "root";
      };
      wantedBy = [ "multi-user.target" ];
    };

    machines.base.runWebServer = true;
    services.nginx.virtualHosts."${config.networking.hostName}.local" = {
      locations."/auth/" = {
        proxyPass =
          "http://127.0.0.1:${builtins.toString service-ports.authui}/auth/";
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
