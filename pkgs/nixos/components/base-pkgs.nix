{ pkgs, config, lib, ... }:
with pkgs;
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
    anixpkgs.nix-deps
    anixpkgs.nix-diffs
    anixpkgs.orchestrator
    anixpkgs.rankserver-cpp
  ];

  services.lorri.enable = true;
}
