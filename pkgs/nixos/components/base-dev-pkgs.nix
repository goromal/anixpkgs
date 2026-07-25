{
  pkgs,
  config,
  lib,
  ...
}:
with import ../dependencies.nix;
let
  cfg = config.mods.opts;
  devshellPkg = anixpkgs.devshell.override { editorName = cfg.editor; };
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
    devshellPkg
    (pkgs.writeShellScriptBin "dsd" ''
      if [[ $# -eq 0 ]]; then
        wsname=$(${pkgs.python3}/bin/python ${devshellPkg.selectWsScript} ~/.devrc)
        if [[ -n "$wsname" ]]; then
          devshell "$wsname" --run dev
        fi
      else
        devshell "$@" --run dev
      fi
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
