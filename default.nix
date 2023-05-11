{ overlays ? []
, ...
}@args:
with import ./dependencies.nix;
import nixpkgs {
  overlays = [
    (import ./overlay.nix)
  ] ++ overlays;
} // args
