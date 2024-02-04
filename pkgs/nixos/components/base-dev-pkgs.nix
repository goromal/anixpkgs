{ pkgs, config, lib, ... }:
with pkgs;
with import ../dependencies.nix { inherit config; }; {
  home.packages = [
    direnv
    anixpkgs.git-cc
    anixpkgs.git-shortcuts
    anixpkgs.setupws
    anixpkgs.listsources
    anixpkgs.pkgshell
    anixpkgs.devshell
    anixpkgs.cpp-helper
    anixpkgs.py-helper
    anixpkgs.rust-helper
    anixpkgs.makepyshell
  ];

  programs.git = {
    package = gitAndTools.gitFull;
    enable = true;
    userName = "Andrew Torgesen";
    userEmail = "andrew.torgesen@gmail.com";
    aliases = {
      aa = "add -A";
      cm = "commit -m";
      co = "checkout";
      s = "status";
      d = "diff";
    };
    extraConfig = {
      init = { defaultBranch = "master"; };
      push = { default = "current"; };
      pull = { default = "current"; };
    };
  };

  services.lorri.enable = true;
}
