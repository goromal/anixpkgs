{ pkgs, config, lib, ... }:
with import ../dependencies.nix { inherit config; };
with pkgs; {
  home.packages = [ terminator ];

  home.file = {
    ".config/terminator/config".source =
      ../res/terminator-config; # https://rigel.netlify.app/#terminal
  };
}
