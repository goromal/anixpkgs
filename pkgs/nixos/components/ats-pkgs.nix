{ pkgs, config, lib, ... }:
with pkgs;
with import ../dependencies.nix { inherit config; };
let cfg = config.mods.x86-graphical;
in {
  imports = [
    ../../python-packages/orchestrator/module.nix
    ../../python-packages/ats-greeting/module.nix
  ];

  services.orchestratord = {
    enable = true;
    rootDir = "${cfg.homeDir}/orchestratord";
  };

  services.ats-greeting = {
    enable = true;
  };
}
