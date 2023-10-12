{ pkgs, config, lib, ... }:
with import ../dependencies.nix { inherit config; }; {
  home.packages = [
    anixpkgs.color-prints
    anixpkgs.git-cc
    anixpkgs.fix-perms
    anixpkgs.secure-delete
    anixpkgs.sunnyside
    anixpkgs.setupws
    anixpkgs.listsources
    anixpkgs.pkgshell
    anixpkgs.devshell
    anixpkgs.cpp-helper
    anixpkgs.py-helper
    anixpkgs.makepyshell
    anixpkgs.make-title
    anixpkgs.pb
    anixpkgs.dirgroups
    anixpkgs.fixfname
    # https://github.com/utdemir/nix-tree
    (pkgs.writeShellScriptBin "nix-deps" ''
      if [[ $# -ge 2 ]]; then
          nix-build $@ --no-out-link | xargs -o ${pkgs.nix-tree}/bin/nix-tree
      elif [[ $# -eq 1 ]]; then
          ${pkgs.nix-tree}/bin/nix-tree "$1"
      else
          ${anixpkgs.color-prints}/bin/echo_red "Must specify either a store path or nix-build rules."
      fi
    '')
    anixpkgs.orchestrator
  ];

  services.lorri.enable = true;
}
