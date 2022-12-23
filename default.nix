{ overlays ? []
, ...
}@args:
with import ./dependencies.nix;
import nixpkgs {
  overlays = [
    (import "${nix-ros-overlay}/overlay.nix")
    (import ./overlay.nix)
  ] ++ overlays;
} // args
