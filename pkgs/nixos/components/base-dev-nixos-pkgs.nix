{ pkgs, config, lib, ... }:
with pkgs;
with import ../dependencies.nix { inherit config; }; {
  imports = [ ./base-dev-pkgs.nix ];

  programs.vim.plugins = with vimPlugins; [ vim-gitgutter YouCompleteMe ];
}
