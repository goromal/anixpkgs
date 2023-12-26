{ pkgs, config, lib, ... }:
with pkgs;
with import ../dependencies.nix { inherit config; };
{
  imports = [
    ./x86-graphical-dev-pkgs.nix
  ];

  dconf.settings = {
    "org/gnome/shell" = {
      "favorite-apps" = [
        "codium.desktop" # ^^^^ TODO works? 
      ];
    };
  };
}
