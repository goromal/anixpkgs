# https://nix.dev/tutorials/nixos/integration-testing-using-virtual-machines.html
# $(nix-build -A driverInteractive minimal-test.nix)/bin/nixos-test-driver
with import ../dependencies.nix;
let
  pkgs = (
    import (fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-${nixos-version}") {
      config = { };
      overlays = [ ];
    }
  );
in
pkgs.testers.runNixOSTest {
  name = "drone-sim";
  nodes = {
    drone =
      { config, pkgs, ... }:
      {
        imports = [ ../configurations/drone-obc-sitl.nix ];
        virtualisation.cores = 4;
        virtualisation.memorySize = 8192;
        virtualisation.diskSize = 8192;
        virtualisation.forwardPorts = [
          {
            from = "host";
            host.port = 4444;
            guest.port = 22;
          }
        ];
      };
    # drone-physics = { config, pkgs, ... }: {
    #   # ...
    # };
  };
  testScript =
    { nodes, ... }:
    ''
      print("Waiting for default target on drone...")
      machines[0].wait_for_unit("default.target")
      print("Checking ROS2 CLI...")
      machines[0].succeed("ros2 topic list")
      print("Checking ROS2 pub/sub...")
      machines[0].succeed(
          "ros2 run demo_nodes_cpp talker >/dev/null 2>&1 & "
          "timeout 120 ros2 topic echo --once /chatter"
      )
      print("Done.")
    '';
}
