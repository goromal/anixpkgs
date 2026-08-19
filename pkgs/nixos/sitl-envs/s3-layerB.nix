# Headless S3 Layer-B: boots the SITL + ROS2/DDS stack, engages the in-firmware
# INDI *outer* loop (CC_TYPE=3, CC3_OUTER_EN=1), and flies a trajectory driven
# by the ROS2 trajectory-server publishing ardupilot_msgs/FlatSetpoint over the
# custom AP_DDS topic (rt/ap/flat_setpoint). Unlike S2 (offboard SET_ATTITUDE_
# TARGET, latency-unstable INDI accel loop) the whole outer loop is in firmware,
# so the flatness + linear-INDI thrust-vector increment runs at the low-latency
# controller rate. Exports the .BIN and reports the INDB outer-loop health
# (fallback fraction + reference-vs-measured tracking).
# Run: nix-build pkgs/nixos/sitl-envs/s3-layerB.nix
with import ../dependencies.nix;
let
  # CC3_B_ACC_FILT sweep knob (Hz): the outer-loop specific-force / thrust-state
  # phase-margin cutoff. Swept in Task B5 to find a stable+active operating point.
  accFilt = 8;
  # Trajectory case flown (single-case smoke; the full battery is Task B6).
  case = "circle_slow";

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
  name = "s3-layerB";
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
        # INDI backend on all axes, RC9 -> CUSTOM_CONTROLLER (109), the C1 inner
        # config (OMG_FILT 80, G1_RP 500), and the Layer-B outer loop enabled
        # with the swept specific-force cutoff.
        services.ardupilot-sim.parameters = lib.mkAfter [
          "CC_TYPE 3"
          "CC_AXIS_MASK 7"
          "RC9_OPTION 109"
          "CC3_OMG_FILT 80"
          "CC3_G1_RP 500"
          "CC3_OUTER_EN 1"
          "CC3_B_ACC_FILT ${toString accFilt}"
        ];
        # Same GPS/EKF warm-up probe as S1/S2/S3-C.
        environment.etc."s3-arm-probe.py".source = ./s3-arm-probe.py;
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
      arm_probe = machines[0].execute("timeout 180 python3 /etc/s3-arm-probe.py 2>&1")[1]

      # Fly: the mavlink runner takes off + engages the custom controller and
      # holds station (writes /tmp/lb_ready when hovering+engaged); the ROS2
      # trajectory-server then streams FlatSetpoint so the in-firmware INDI
      # outer loop flies ${case}.
      machines[0].execute("rm -f /tmp/lb_ready")
      machines[0].execute(
          "(timeout 600 python3 -m indi_harness.sitl.baseline_outer"
          " --url tcp:127.0.0.1:5790 --out /tmp/s3_layerB --engage-rc 9"
          " --ready-file /tmp/lb_ready --cases ${case} >/tmp/runner.log 2>&1 &"
          " echo $! >/tmp/runner.pid)"
      )
      try:
          # wait for takeoff+engage (the ready file)
          machines[0].wait_for_file("/tmp/lb_ready", timeout=300)
          # start the trajectory-server (rclpy + ardupilot_msgs), streaming until
          # the runner finishes the hold and we stop it.
          machines[0].execute(
              "(PYTHONPATH=${indiSitePackages} ${rosPy}/bin/python3"
              " -m indi_harness.offboard.traj_server --case ${case}"
              " >/tmp/traj.log 2>&1 & echo $! >/tmp/traj.pid)"
          )
          # wait for the runner to complete the hold + land phase
          machines[0].succeed(
              "PID=$(cat /tmp/runner.pid); for i in $(seq 1 600); do "
              "kill -0 $PID 2>/dev/null || break; sleep 1; done; "
              "test -s /tmp/s3_layerB/s3_layerB_flown.json"
          )
      except Exception:
          print("=== runner.log ==="); print(machines[0].execute("cat /tmp/runner.log 2>/dev/null | tail -40")[1])
          print("=== traj.log ==="); print(machines[0].execute("cat /tmp/traj.log 2>/dev/null | tail -40")[1])
          print("=== arm probe ==="); print(arm_probe)
          print("=== ardusitl journal ==="); print(machines[0].execute("journalctl -u ardusitl --no-pager | grep -iE 'prearm|arm|ekf|gps|home|custom' | grep -iv 'Loaded defaults' | tail -40")[1])
          raise
      finally:
          machines[0].execute("kill -INT $(cat /tmp/traj.pid) 2>/dev/null || true; sleep 1")

      print("=== traj_server log ===")
      print(machines[0].execute("tail -8 /tmp/traj.log 2>/dev/null")[1])

      # Export the newest .BIN (outer-loop health source of truth).
      machines[0].succeed("cp $(ls -t /data/drone/ardusitl/logs/*.BIN | head -1) /tmp/s3_layerB/s3_layerB.BIN")
      machines[0].copy_from_vm("/tmp/s3_layerB/s3_layerB.BIN", "")

      # INDB outer-loop health: fallback fraction over the flight + the
      # reference-vs-measured position RMSE while the outer loop was active.
      print(machines[0].succeed(
          "python3 -c \""
          "import numpy as np; from indi_harness.sitl.binlog import read_outer_health; "
          "h=read_outer_health('/tmp/s3_layerB/s3_layerB.BIN'); "
          "n=len(h['time_us']); fb=h['fallback']; act=fb==0; "
          "err=np.linalg.norm(h['ref_p'][act]-h['meas_p'][act],axis=1) if act.any() else np.array([0.0]); "
          "print('INDB msgs', n, 'active_frac', round(float((act).mean()),3) if n else 0, "
          "'track_rms_m', round(float(np.sqrt((err**2).mean())),3), "
          "'track_max_m', round(float(err.max()),3))\""
      ))
    '';
}
