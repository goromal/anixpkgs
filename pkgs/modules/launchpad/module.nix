{
  pkgs,
  config,
  lib,
  ...
}:
with import ../../nixos/dependencies.nix;
let
  cfg = config.services.launchpad;
  # Extend system pkgs (which carries jetpack CUDA config) with the anixpkgs
  # overlay so withPackages sees both CUDA-enabled stdlib packages and the
  # custom anixpkgs Python packages (geometry, pysignals, etc.) in one set.
  extendedPkgs = pkgs.extend (import ../../../overlay.nix);
  pythonEnv = extendedPkgs.python313.withPackages (ps: [ ps.jupyterlab ] ++ (cfg.pythonPackages ps));
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
    scratchpadRepo = lib.mkOption {
      type = lib.types.str;
      description = "Git URL of the scratchpad repo to clone if notebookDir is not yet a repo";
      default = "git@github.com:goromal/scratchpad.git";
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
        ExecStartPre = pkgs.writeShellScript "launchpad-pre" ''
          if [[ ! -d "${cfg.notebookDir}/.git" ]]; then
            ${pkgs.git}/bin/git clone ${cfg.scratchpadRepo} ${cfg.notebookDir}
          fi
        '';
        ExecStart = "${pythonEnv}/bin/jupyter lab --no-browser --ip=0.0.0.0 --port=${builtins.toString cfg.port} --notebook-dir=${cfg.notebookDir} --ServerApp.token=''";
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
