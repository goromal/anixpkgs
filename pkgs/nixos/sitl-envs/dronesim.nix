# https://nix.dev/tutorials/nixos/integration-testing-using-virtual-machines.html
# $(nix-build -A driverInteractive minimal-test.nix)/bin/nixos-test-driver
with import ../dependencies.nix;
let
  pkgs = (import (fetchTarball
    "https://github.com/NixOS/nixpkgs/tarball/nixos-${nixos-version}") {
      config = { };
      overlays = [ ];
    });
in pkgs.testers.runNixOSTest {
  name = "drone-sim";
  nodes = {
    drone = { config, pkgs, ... }: {
      imports = [ ../configurations/drone-sitl.nix ];
      virtualisation.forwardPorts = [ { from = "host"; host.port = 2222; guest.port = 22; } ];
    };
    # drone-physics = { config, pkgs, ... }: {
    #   # ...
    # };
  };
  testScript = { nodes, ... }: ''
    machines[0].wait_for_unit("default.target")
  '';
}
