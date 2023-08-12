{ pkgs, flakeInputs }:
let nixos-lib = import (flakeInputs.nixpkgs + "/nixos/lib") { };
in nixos-lib.runTest {
  imports = [ ./sitl-env.nix ];
  hostPkgs = pkgs;
}
