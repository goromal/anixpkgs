final: prev: with prev.lib;
let 
  flakeInputs = let
    flake-compat = import (
      let lock = builtins.fromJSON (builtins.readFile ./flake.lock); in
      fetchTarball {
        url = "https://github.com/edolstra/flake-compat/archive/${lock.nodes.flake-compat.locked.rev}.tar.gz";
        sha256 = lock.nodes.flake-compat.locked.narHash;
      }
    );
    in final.config.flakeInputs or (flake-compat { src = final.lib.cleanSource ./.; }).defaultNix.inputs;
in (foldr composeExtensions (_: _: {}) [
  (import ./pkgs)
] final prev) // { inherit flakeInputs; }
