final: prev:
with prev.lib;
let
  # Fetched via flake.lock (not flakeInputs) to avoid infinite recursion:
  # the overlay's attribute names may not depend on `final`.
  nix-ros-overlay =
    let
      lock = builtins.fromJSON (builtins.readFile ./flake.lock);
    in
    fetchTarball {
      url = "https://github.com/lopsided98/nix-ros-overlay/archive/${lock.nodes.nix-ros-overlay.locked.rev}.tar.gz";
      sha256 = lock.nodes.nix-ros-overlay.locked.narHash;
    };
  flakeInputs =
    let
      flake-compat = import (
        let
          lock = builtins.fromJSON (builtins.readFile ./flake.lock);
        in
        fetchTarball {
          url = "https://github.com/edolstra/flake-compat/archive/${lock.nodes.flake-compat.locked.rev}.tar.gz";
          sha256 = lock.nodes.flake-compat.locked.narHash;
        }
      );
    in
    final.config.flakeInputs or (flake-compat {
      src = final.lib.cleanSource ./.;
    }).defaultNix.inputs;
in
(foldr composeExtensions (_: _: { }) [
  (import "${nix-ros-overlay}/overlay.nix")
  (import ./pkgs)
] final prev)
// {
  inherit flakeInputs;
}
