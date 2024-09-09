{ pkgs, config, lib, ... }:
with import ../dependencies.nix;
let cfg = config.mods.opts;
in {
  home.packages = [
    pkgs.direnv
    anixpkgs.flake-update
    anixpkgs.git-cc
    anixpkgs.git-shortcuts
    anixpkgs.setupws
    anixpkgs.listsources
    anixpkgs.pkgshell
    (anixpkgs.devshell.override { editorName = cfg.editor; })
    (pkgs.writeShellScriptBin "dsd" ''
      devshell $@ --run dev
    '')
    anixpkgs.cpp-helper
    anixpkgs.py-helper
    anixpkgs.rust-helper
    anixpkgs.makepyshell
  ];

  programs.git = {
    package = pkgs.gitAndTools.gitFull;
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

  programs.vim.plugins = lib.mkIf (cfg.standalone == false)
    (with pkgs.vimPlugins; [ vim-gitgutter YouCompleteMe ]);
}
