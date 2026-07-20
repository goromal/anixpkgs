# Headless S2: offboard ROS2 outer loop flying the S1 battery through the
# stock inner loop via SET_ATTITUDE_TARGET (design doc S2 exit).
# Run: nix-build pkgs/nixos/sitl-envs/s2-offboard.nix
with import ../dependencies.nix;
let
  pkgs = (
    import (fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-${nixos-version}") {
      config = { };
      overlays = [ ];
    }
  );
  # rclpy lives only in the ROS overlay's python (built on its own nixpkgs),
  # not in the guest's python313.withPackages env that carries indi_harness.
  # Run the offboard node through the ROS python, with the indi_harness env's
  # site-packages on PYTHONPATH so numpy/pymavlink/rosbags/indi_harness come
  # along (both are CPython 3.13, ABI-compatible). Baked here rather than
  # guessed in-guest so the interpreter paths are exact.
  rosPy = ros-pkgs.rosPackages.jazzy.buildEnv {
    paths = with ros-pkgs.rosPackages.jazzy; [
      ros-core
      demo-nodes-cpp
      demo-nodes-py
      rosbag2
      rosbag2-storage-mcap
    ];
  };
  indiPy = anixpkgs.python313.withPackages (ps: [ ps.indi-harness ]);
  indiSitePackages = "${indiPy}/lib/python3.13/site-packages";
in
pkgs.testers.runNixOSTest {
  name = "s2-offboard";
  nodes = {
    drone =
      { config, pkgs, lib, ... }:
      {
        imports = [ ../configurations/drone-obc-sitl.nix ];
        virtualisation.cores = 4;
        virtualisation.memorySize = 8192;
        virtualisation.diskSize = 8192;
        # thrust field = thrust, not climb rate (SET_ATTITUDE_TARGET)
        services.ardupilot-sim.parameters = lib.mkAfter [ "GUID_OPTIONS 8" ];
        # Same GPS/EKF warm-up + diagnostic probe S1 uses: arm() only passes
        # once prearm clears, but the vehicle needs a sim GPS lock before it
        # will climb on NAV_TAKEOFF. Running this first warms the EKF and
        # prints STATUSTEXT/GPS/param lines so any arm/takeoff failure in the
        # headless battery is explainable from the log.
        environment.etc."s2-arm-probe.py".text = ''
          import time
          from pymavlink import mavutil

          c = mavutil.mavlink_connection("tcp:127.0.0.1:5790")
          c.wait_heartbeat(timeout=120)
          print(f"probe: heartbeat sys={c.target_system} comp={c.target_component}", flush=True)
          c.mav.request_data_stream_send(c.target_system, c.target_component,
              mavutil.mavlink.MAV_DATA_STREAM_ALL, 4, 1)
          for p in (b"ARMING_CHECK", b"FS_THR_ENABLE", b"SIM_SPEEDUP", b"GPS_TYPE", b"GUID_OPTIONS"):
              c.mav.param_request_read_send(c.target_system, c.target_component, p, -1)
          t0 = time.time()
          arms = 0
          seen_rc = seen_fix = None
          while time.time() - t0 < 90:
              if (arms == 0 and time.time() - t0 > 10) or (arms == 1 and time.time() - t0 > 60):
                  c.mav.command_long_send(c.target_system, c.target_component,
                      mavutil.mavlink.MAV_CMD_COMPONENT_ARM_DISARM, 0, 1, 0, 0, 0, 0, 0, 0)
                  arms += 1
                  print(f"probe: ARM attempt {arms} at t={time.time()-t0:.0f}s", flush=True)
              m = c.recv_match(type=["STATUSTEXT", "COMMAND_ACK", "PARAM_VALUE",
                                     "RC_CHANNELS", "GPS_RAW_INT", "HEARTBEAT"],
                               blocking=True, timeout=2)
              if m is None:
                  continue
              k = m.get_type()
              if k == "STATUSTEXT":
                  print(f"probe: STATUSTEXT sev={m.severity} {m.text}", flush=True)
              elif k == "COMMAND_ACK":
                  print(f"probe: ACK cmd={m.command} result={m.result}", flush=True)
              elif k == "PARAM_VALUE":
                  print(f"probe: PARAM {m.param_id} = {m.param_value}", flush=True)
              elif k == "RC_CHANNELS" and seen_rc is None:
                  seen_rc = (m.chan1_raw, m.chan2_raw, m.chan3_raw, m.chan4_raw)
                  print(f"probe: RC_CHANNELS 1-4 = {seen_rc}", flush=True)
              elif k == "GPS_RAW_INT" and m.fix_type != seen_fix:
                  seen_fix = m.fix_type
                  print(f"probe: GPS fix_type -> {m.fix_type} at t={time.time()-t0:.0f}s", flush=True)
              elif k == "HEARTBEAT" and (m.base_mode & mavutil.mavlink.MAV_MODE_FLAG_SAFETY_ARMED):
                  print(f"probe: ARMED at t={time.time()-t0:.0f}s", flush=True)
                  c.mav.command_long_send(c.target_system, c.target_component,
                      mavutil.mavlink.MAV_CMD_COMPONENT_ARM_DISARM, 0, 0, 0, 21196, 0, 0, 0, 0)
                  break
          print("probe: done", flush=True)
        '';
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
      machines[0].succeed("python3 -c 'import indi_harness.offboard.bridge'")
      # GPS/EKF warm-up + diagnostics (see s2-arm-probe.py) before flying.
      print(machines[0].execute("timeout 180 python3 /etc/s2-arm-probe.py 2>&1")[1])
      # §L: bag of what the graph saw, /ap/time included for the time bridge.
      # sqlite3 storage (default), not mcap: the non-interactive test harness
      # cannot cleanly SIGINT-finalize the recorder, and an unfinalized mcap
      # is unreadable (missing footer/end-magic). A sqlite3 .db3 is crash-safe
      # (valid after each committed transaction) and `ros2 bag reindex`
      # regenerates its metadata.yaml. The mcap storage plugin IS installed
      # (rosbag2-storage-mcap) and records — proven separately below.
      machines[0].succeed("(ros2 bag record -s mcap -o /tmp/mcap_probe /ap/time >/dev/null 2>&1 & echo $! >/tmp/mp.pid); sleep 5; kill -INT $(cat /tmp/mp.pid) 2>/dev/null; sleep 2; ls -la /tmp/mcap_probe/*.mcap")
      machines[0].execute(
          "cd /tmp && (ros2 bag record -s sqlite3 -o s2bag "
          "/ap/pose/filtered /ap/twist/filtered /ap/time "
          "/indi/ref_pose /indi/cmd_attitude >/tmp/bag.log 2>&1 & "
          "echo $! >/tmp/bag.pid)"
      )
      try:
          # baseline needs rclpy -> ROS python + indi_harness on PYTHONPATH
          # --no-indi: PD+ff on the flatness reference. The INDI accel
          # increment is unstable offboard (at ~27 Hz /ap/pose with DDS+MAVLink
          # command-path latency the previous-command and measured specific
          # force do not cancel -> f_cmd winds up; observed commanded tilt
          # >130 deg, thrust surrogate ->1e4). Stabilizing INDI offboard needs
          # a faster/lower-latency inner path (design-doc S3+); S2 flies the
          # battery with the stable flatness PD+ff outer loop.
          machines[0].succeed(
              "PYTHONPATH=${indiSitePackages} timeout 3600 ${rosPy}/bin/python3"
              " -m indi_harness.offboard.baseline"
              " --url tcp:127.0.0.1:5790 --no-indi"
              " --logs-dir /data/drone/ardusitl/logs"
              " --out /tmp/s2_offboard >&2"
          )
      except Exception:
          print("=== baseline failure diagnostics ===")
          print(machines[0].execute("journalctl -u ardusitl --no-pager | grep -iE 'prearm|arm|guided|ekf|gps|home' | grep -iv 'Loaded defaults' | tail -40")[1])
          print(machines[0].execute("cat /tmp/bag.log 2>/dev/null | tail -20")[1])
          raise
      # Stop the recorder (SIGINT the exact PID) then rebuild the index: a
      # non-interactive SIGINT does not reliably write metadata.yaml, but the
      # sqlite3 .db3 is crash-safe and `ros2 bag reindex -s sqlite3`
      # regenerates it.
      # Stop the recorder and WAIT for it to actually exit before reindexing —
      # otherwise the sqlite3 db is still locked and reindex fails.
      machines[0].execute(
          "PID=$(cat /tmp/bag.pid); kill -INT $PID 2>/dev/null || true; "
          "for i in $(seq 1 20); do kill -0 $PID 2>/dev/null || break; sleep 1; done; "
          "kill -9 $PID 2>/dev/null || true; "
          "pkill -9 -f 'ros2 bag record' 2>/dev/null || true; sleep 2"
      )
      machines[0].execute("test -f /tmp/s2bag/metadata.yaml || ros2 bag reindex -s sqlite3 /tmp/s2bag")
      print(machines[0].execute("tail -6 /tmp/bag.log; echo '--- bag dir ---'; ls -la /tmp/s2bag")[1])

      # Hard requirement: the scored 5-case battery JSON. Export it + the raw
      # bag before the (best-effort) latency analysis, so control diagnosis and
      # the exit-gate artifact survive any bag-tooling hiccup.
      machines[0].succeed("test -s /tmp/s2_offboard/s2_offboard.json")
      machines[0].succeed("cd /tmp && tar czf /tmp/s2_offboard/s2bag.tgz s2bag")
      machines[0].copy_from_vm("/tmp/s2_offboard/s2_offboard.json", "")
      machines[0].copy_from_vm("/tmp/s2_offboard/s2bag.tgz", "")
      print(machines[0].succeed("cat /tmp/s2_offboard/s2_offboard.json"))

      # Best-effort latency report (§L command-path evidence).
      rc, _ = machines[0].execute("python3 -m indi_harness.offboard.bags /tmp/s2bag --json /tmp/s2_offboard/latency.json 2>/tmp/lat.err")
      if rc == 0:
          machines[0].copy_from_vm("/tmp/s2_offboard/latency.json", "")
          print(machines[0].succeed("cat /tmp/s2_offboard/latency.json"))
      else:
          print("=== latency analysis failed (non-fatal) ===")
          print(machines[0].execute("cat /tmp/lat.err | tail -10")[1])
    '';
}
