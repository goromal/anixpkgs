{ config, pkgs, lib, ... }:
with pkgs;
with lib; {
  home.packages = [ tmux ];

  home.file = {
    ".tmux.conf" = {
      text = ''
        set-option -g default-shell /run/current-system/sw/bin/bash
        set-window-option -g mode-keys vi
        set -g default-terminal "screen-256color"
        set -ga terminal-overrides ',screen-256color:Tc'
      '';
    };
  };
}
