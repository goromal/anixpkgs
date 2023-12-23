{ pkgs, config, lib, ... }:
with pkgs;
with import ../dependencies.nix { inherit config; };
let cfg = config.mods.x86-graphical;
orchestratorPkg = anixpkgs.orchestrator;
in {
  imports = [
    ../../python-packages/orchestrator/module.nix
    ../../python-packages/ats-greeting/module.nix
  ];

  services.orchestratord = {
    enable = true;
    rootDir = "${cfg.homeDir}/orchestratord";
    inherit orchestratorPkg;
  };

  services.ats-greeting = {
    enable = true;
    inherit orchestratorPkg;
  };
}
