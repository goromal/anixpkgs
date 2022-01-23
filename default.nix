{ overlays ? []
, ...
}@args:
with import ./dependencies.nix;
import nix-ros-overlay { 
  inherit nixpkgs;
  overlays = [ (import ./overlay.nix) ] ++ overlays;
} // args
