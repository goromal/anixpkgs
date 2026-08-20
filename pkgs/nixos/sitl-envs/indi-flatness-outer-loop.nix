# In-firmware INDI flatness outer loop: boots the SITL + ROS2/DDS stack, engages
# the in-firmware INDI *outer* loop (CC_TYPE=3, CC3_OUTER_EN=1), and flies a
# trajectory driven by the ROS2 trajectory-server publishing
# ardupilot_msgs/FlatSetpoint over the custom AP_DDS topic (rt/ap/flat_setpoint).
# Unlike the off-board flatness controller (SET_ATTITUDE_TARGET, latency-unstable
# INDI accel loop) the whole outer loop is in firmware, so the flatness +
# linear-INDI thrust-vector increment runs at the low-latency controller rate.
# This is the most comprehensive drone gate: it exercises the full stack (SITL +
# ROS2/DDS + in-firmware outer loop + INDI inner loop) and asserts flat-tracking,
# no altitude runaway, and the DDS-staleness fallback path.
# Run: nix-build pkgs/nixos/sitl-envs/indi-flatness-outer-loop.nix
with import ../dependencies.nix;
let
  # CC3_B_ACC_FILT (Hz): the outer-loop specific-force / thrust-state phase-margin
  # cutoff. Stable+active across a 4-30 Hz sweep; 8 is the firmware default. The
  # gate flies the full battery at this cutoff.
  accFilt = 8;

  pkgs = (
    import (fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-${nixos-version}") {
      config = { };
      overlays = [ ];
    }
  );
  # ROS python (rclpy) for the trajectory-server, with the custom ardupilot_msgs
  # interface package so `from ardupilot_msgs.msg import FlatSetpoint` resolves.
  rosPy = ros-pkgs.rosPackages.jazzy.buildEnv {
    paths =
      (with ros-pkgs.rosPackages.jazzy; [
        ros-core
        geometry-msgs
      ])
      ++ [ anixpkgs.ardupilot-msgs ];
  };
  indiPy = anixpkgs.python313.withPackages (ps: [ ps.indi-harness ]);
  indiSitePackages = "${indiPy}/lib/python3.13/site-packages";
in
pkgs.testers.runNixOSTest {
  name = "indi-flatness-outer-loop";
  nodes = {
    drone =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      {
        imports = [ ../configurations/drone-obc-sitl.nix ];
        virtualisation.cores = 4;
        virtualisation.memorySize = 8192;
        virtualisation.diskSize = 8192;
        # INDI backend on all axes, RC9 -> CUSTOM_CONTROLLER (109), the inner
        # rate loop tuned for angular-accel inversion (OMG_FILT 80, G1_RP 500),
        # and the flatness outer loop enabled with the swept specific-force cutoff.
        services.ardupilot-sim.parameters = lib.mkAfter [
          "CC_TYPE 3"
          "CC_AXIS_MASK 7"
          "RC9_OPTION 109"
          "CC3_OMG_FILT 80"
          "CC3_G1_RP 500"
          "CC3_OUTER_EN 1"
          # Attitude-only outer loop: drive q_ref/w_ff/dw_ff into the inner rate
          # loop, leave collective to the stock altitude controller. Driving the
          # collective from the outer loop (CC3_B_THR_EN=1) self-references into an
          # altitude runaway (throttle -> thrust-state -> thrust-vector), so it is
          # disabled here; the RPM-fed thrust path is deferred to hardware.
          "CC3_B_THR_EN 0"
          "CC3_B_ACC_FILT ${toString accFilt}"
        ];
        # Shared GPS/EKF warm-up probe (same one the other SITL gates use).
        environment.etc."arm-probe.py".source = ./arm-probe.py;
        # Battery gate scorer (flat-tracking + omega_dot-inversion + fallback).
        environment.etc."indi-flatness-outer-loop-score.py".source = ./indi-flatness-outer-loop-score.py;
      };
  };
  testScript =
    { nodes, ... }:
    ''
      machines[0].wait_for_unit("default.target")
      machines[0].wait_for_unit("ardusitl.service")
      machines[0].wait_for_unit("ardurouter.service")
      machines[0].wait_for_unit("microxrce-agent.service")
      machines[0].wait_until_succeeds("ss -tn state established '( dport = :5760 )' | grep -q 5760", timeout=120)
      machines[0].wait_until_succeeds("ss -tln '( sport = :5790 )' | grep -q 5790", timeout=60)
      machines[0].wait_until_succeeds("timeout 60 ros2 topic list | grep -q '^/ap/pose'", timeout=600)
      machines[0].wait_until_succeeds("timeout 60 ros2 topic list | grep -q '^/ap/clock'", timeout=120)
      machines[0].succeed("python3 -c 'import indi_harness.sitl.baseline_outer'")

      # GPS/EKF warm-up (captured; surfaced only on failure).
      arm_probe = machines[0].execute("timeout 180 python3 /etc/arm-probe.py 2>&1")[1]

      # Fly the FULL battery: the mavlink runner takes off + engages the custom
      # controller once, then holds station case-by-case, writing {case,origin}
      # to /tmp/lb_ready before each hold and unlinking it between cases. The
      # trajectory-server runs in battery mode (--ready-file): it follows the
      # ready-file, streaming each case's FlatSetpoint relative to that case's
      # hover origin, and stops between cases -> the backend falls back (the
      # DDS-staleness sub-case, exercised at every case boundary).
      machines[0].execute("rm -f /tmp/lb_ready")
      machines[0].execute(
          "(timeout 900 python3 -m indi_harness.sitl.baseline_outer"
          " --url tcp:127.0.0.1:5790 --out /tmp/flight --engage-rc 9"
          " --ready-file /tmp/lb_ready >/tmp/runner.log 2>&1 &"
          " echo $! >/tmp/runner.pid)"
      )
      try:
          # wait for takeoff+engage (first case's ready file), then start the
          # battery-mode trajectory-server (rclpy + ardupilot_msgs).
          machines[0].wait_for_file("/tmp/lb_ready", timeout=300)
          machines[0].execute(
              "(PYTHONPATH=${indiSitePackages} ${rosPy}/bin/python3"
              " -m indi_harness.offboard.traj_server --ready-file /tmp/lb_ready"
              " >/tmp/traj.log 2>&1 & echo $! >/tmp/traj.pid)"
          )
          # wait for the runner to finish the whole battery (writes flown.json)
          machines[0].succeed(
              "PID=$(cat /tmp/runner.pid); for i in $(seq 1 900); do "
              "kill -0 $PID 2>/dev/null || break; sleep 1; done; "
              "test -s /tmp/flight/s3_layerB_flown.json"
          )
      except Exception:
          print("=== runner.log ==="); print(machines[0].execute("cat /tmp/runner.log 2>/dev/null | tail -40")[1])
          print("=== traj.log ==="); print(machines[0].execute("cat /tmp/traj.log 2>/dev/null | tail -40")[1])
          print("=== arm probe ==="); print(arm_probe)
          print("=== ardusitl journal ==="); print(machines[0].execute("journalctl -u ardusitl --no-pager | grep -iE 'prearm|arm|ekf|gps|home|custom' | grep -iv 'Loaded defaults' | tail -40")[1])
          raise
      finally:
          machines[0].execute("kill -INT $(cat /tmp/traj.pid) 2>/dev/null || true; sleep 1")

      # Export the newest .BIN (outer-loop health source of truth).
      machines[0].succeed("cp $(ls -t /data/drone/ardusitl/logs/*.BIN | head -1) /tmp/flight/flight.BIN")
      machines[0].copy_from_vm("/tmp/flight/flight.BIN", "")

      # Hard gate (the one comprehensive drone check): all 5 cases flown via DDS,
      # tracked (RMS < 1.5 m -> forces the figure-eight win, and is itself proof
      # the inner INDI loop delivers real torque), no altitude runaway, and the
      # DDS-staleness->fallback path exercised between cases. Quiet on success
      # (summary line + PASS); on failure the runner/traj logs are surfaced above.
      try:
          print(machines[0].succeed(
              "python3 /etc/indi-flatness-outer-loop-score.py"
              " /tmp/flight/flight.BIN /tmp/flight/s3_layerB_flown.json"))
      except Exception:
          print("=== traj_server log ==="); print(machines[0].execute("tail -12 /tmp/traj.log 2>/dev/null")[1])
          print("=== runner.log ==="); print(machines[0].execute("tail -20 /tmp/runner.log 2>/dev/null")[1])
          raise
    '';
}
