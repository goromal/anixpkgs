{ pkgs, config, lib, ... }:
with pkgs;
with import ../dependencies.nix { inherit config; }; {
  home.packages = [
    docker
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
    anixpkgs.anix-version
    anixpkgs.anix-upgrade
    anixpkgs.orchestrator
    anixpkgs.rankserver-cpp
  ];

  home.file = {
    ".anix-version".text =
      if local-build then "Local Build" else "v${anix-version}";
  };

  services.lorri.enable = true;
}
