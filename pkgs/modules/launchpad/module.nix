{
  pkgs,
  config,
  lib,
  ...
}:
with import ../../nixos/dependencies.nix;
let
  cfg = config.services.launchpad;
  pythonEnv = anixpkgs.python313.withPackages (
    ps: [ ps.jupyterlab ] ++ (cfg.pythonPackages ps)
  );
in
{
  options.services.launchpad = {
    enable = lib.mkEnableOption "launchpad hardware-accelerated Jupyter notebook server";
    port = lib.mkOption {
      type = lib.types.port;
      description = "Port to run the Jupyter server on";
      default = service-ports.launchpad;
    };
    notebookDir = lib.mkOption {
      type = lib.types.str;
      description = "Directory to serve notebooks from";
      default = "/data/andrew/launchpad";
    };
    pythonPackages = lib.mkOption {
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      description = "Additional Python packages (function from python313 package set to list)";
      default = _ps: [ ];
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.notebookDir} 0755 andrew dev -"
    ];

    systemd.services.launchpad = {
      enable = true;
      description = "Launchpad Jupyter Notebook Server";
      unitConfig = {
        StartLimitIntervalSec = 0;
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pythonEnv}/bin/jupyter lab --no-browser --ip=0.0.0.0 --port=${builtins.toString cfg.port} --notebook-dir=${cfg.notebookDir}";
        ReadWritePaths = [
          cfg.notebookDir
          "/tmp"
        ];
        WorkingDirectory = cfg.notebookDir;
        Restart = "always";
        RestartSec = 5;
        User = "andrew";
        Group = "dev";
        Environment = [ "HOME=/data/andrew" ];
      };
      wantedBy = [ "multi-user.target" ];
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
