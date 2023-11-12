{ pkgs, config, lib, ... }:
with pkgs; {
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
      com = "checkout master";
      pom = "pull origin master";
    };
    extraConfig = {
      init = { defaultBranch = "master"; };
      push = { default = "current"; };
      pull = { default = "current"; };
    };
  };
}
