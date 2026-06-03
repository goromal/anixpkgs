{
  pkgs,
  config,
  lib,
  ...
}:
with import ../dependencies.nix;
let
  cfg = config.mods.opts;
in
{
  home.packages = [
    pkgs.direnv
    anixpkgs.aapis-grpcurl
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
    pkgs.gh
    pkgs.universal-ctags
  ];

  programs.git = {
    package = pkgs.gitFull;
    enable = true;
    settings = {
      user = {
        name = "Andrew Torgesen";
        email = "andrew.torgesen@gmail.com";
      };
      alias = {
        aa = "add -A";
        cm = "commit -m";
        co = "checkout";
        cp = "cherry-pick";
        s = "status";
        d = "diff";
      };
      init = {
        defaultBranch = "master";
      };
      push = {
        default = "current";
      };
      pull = {
        default = "current";
      };
    };
  };

  services.lorri.enable = true;

  programs.vim.plugins = lib.mkIf (cfg.standalone == false) (
    with pkgs.vimPlugins;
    [
      vim-gitgutter
      YouCompleteMe
    ]
  );

}
