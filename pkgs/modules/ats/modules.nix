{ pkgs, config, lib, ... }:
with pkgs;
with lib;
with import ../dependencies.nix { inherit config; };
let
  globalCfg = config.machines.base;
  cfg = config.services.ats;
  oPathPkgs = with anixpkgs; let
    ats-rcrsync = rcrsync.override { cloudDirs = globalCfg.cloudDirs; };
    ats-authm = authm.override { rcrsync = ats-rcrsync; };
  in [
    rclone
    wiki-tools
    task-tools
    ats-rcrsync
    mp4
    mp4unite
    goromail
    gmail-parser
    scrape
    ats-authm
    providence-tasker
  ];
  mkOneshotTimedService = { name, execScript, timerConfig }: {}; # ^^^^ TODO
in {
  options.services.ats = {
    enable = mkEnableOption "enable ATS services";
  };

  imports = [
    ../python-packages/orchestrator/module.nix
  ];

  config = mkIf cfg.enable {
    services.orchestratord = {
      enable = true;
      orchestratorPkg = anixpkgs.orchestrator;
      pathPkgs = oPathPkgs;
    };

    # ^^^^ TODO
  };
}
