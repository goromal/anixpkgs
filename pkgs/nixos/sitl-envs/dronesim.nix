# https://nix.dev/tutorials/nixos/integration-testing-using-virtual-machines.html
# $(nix-build -A driverInteractive minimal-test.nix)/bin/nixos-test-driver
with import ../dependencies.nix;
let
  pkgs = (import (fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-${nixos-version}") {
    config = { };
    overlays = [ ];
  });
in pkgs.testers.runNixOSTest {
  name = "drone-sim";
  nodes = {
    drone = { config, pkgs, ... }: {
      imports = [ ../configurations/drone-sitl.nix ];
    };
    # drone-physics = { config, pkgs, ... }: {
    #   # ...
    # };
  };
  testScript = { nodes, ... }: ''
    # ...
  '';
}
