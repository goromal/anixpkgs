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
      print("Waiting for Ardupilot SITL...")
      machines[0].wait_for_unit("ardusitl.service")
      print("Waiting for mavlink-router...")
      machines[0].wait_for_unit("ardurouter.service")
      print("Checking that mavlink-router is connected to the SITL...")
      machines[0].wait_until_succeeds("ss -tn state established '( dport = :5760 )' | grep -q 5760", timeout=120)
      print("Checking that mavlink-router is listening for GCS connections...")
      machines[0].wait_until_succeeds("ss -tln '( sport = :5790 )' | grep -q 5790", timeout=60)
      print("Waiting for the Micro XRCE-DDS agent...")
      machines[0].wait_for_unit("microxrce-agent.service")
      print("Checking that Ardupilot's AP_DDS client publishes into the ROS2 graph...")
      machines[0].wait_until_succeeds("ros2 topic list | grep -q '^/ap/'", timeout=120)
      machines[0].succeed("timeout 60 ros2 topic echo --once /ap/time")
      print("Checking ROS2 CLI...")
      machines[0].succeed("ros2 topic list")
      print("Checking ROS2 pub/sub...")
      machines[0].execute("ros2 run demo_nodes_cpp talker >/dev/null 2>&1 &")
      # The explicit message type makes echo subscribe and block for data
      # instead of exiting immediately when the talker's publisher hasn't
      # been discovered yet (a race this loses on slow CI runners).
      machines[0].wait_until_succeeds(
          "timeout 30 ros2 topic echo --once /chatter std_msgs/msg/String",
          timeout=120,
      )
      print("Done.")
    '';
}
