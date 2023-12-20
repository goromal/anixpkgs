{ pkgs, config, lib, ... }:
with pkgs;
with import ../dependencies.nix { inherit config; }; {
  imports = [
    ./base-pkgs.nix
    ./base-dev-pkgs.nix
    ../../bash-packages/nix-tools/module.nix
  ];

  home.packages = [ docker tmux ];

  programs.anix-tools = {
    enable = true;
    inherit anixpkgs;
  };

  home.file = {
    ".anix-version".text =
      if local-build then "Local Build" else "v${anix-version}";
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
