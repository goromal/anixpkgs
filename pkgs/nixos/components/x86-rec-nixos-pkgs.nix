{ pkgs, config, lib, ... }:
with import ../dependencies.nix { inherit config; }; {
  imports = [ ./x86-rec-pkgs.nix ];
}
