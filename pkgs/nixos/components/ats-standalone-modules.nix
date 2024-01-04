{ pkgs, config, lib, ... }:
with import ../dependencies.nix { inherit config; };
let anixsrc2 = (builtins.fetchTarball
      "https://github.com/goromal/anixpkgs/archive/refs/heads/dev/ats-home.tar.gz"); # TODO REMOVE
in {
  imports = [
    ${anixsrc2}/pkgs/python-packages/orchestrator/module.nix
  ];

  config = {
    services.orchestratord = {
      enable = true;
      isNixOS = false;
    };
  };
}
