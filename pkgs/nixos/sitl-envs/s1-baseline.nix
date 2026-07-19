# Headless S1 baseline: boots the SITL stack and flies the stock-controller
# trajectory battery, exporting RMSE artifacts (design doc S1 exit).
# Run: nix-build pkgs/nixos/sitl-envs/s1-baseline.nix
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
  name = "s1-baseline";
  nodes = {
    drone =
      { config, pkgs, ... }:
      {
        imports = [ ../configurations/drone-obc-sitl.nix ];
        virtualisation.cores = 4;
        virtualisation.memorySize = 8192;
        virtualisation.diskSize = 8192;
        # Diagnostic probe: prints prearm STATUSTEXT / ACKs / key params so
        # arming failures in the headless battery are explainable from logs.
        environment.etc."s1-arm-probe.py".text = ''
          import time
          from pymavlink import mavutil

          c = mavutil.mavlink_connection("tcp:127.0.0.1:5790")
          c.wait_heartbeat(timeout=120)
          print(f"probe: heartbeat sys={c.target_system} comp={c.target_component}", flush=True)
          c.mav.request_data_stream_send(c.target_system, c.target_component,
              mavutil.mavlink.MAV_DATA_STREAM_ALL, 4, 1)
          for p in (b"ARMING_CHECK", b"FS_THR_ENABLE", b"SIM_SPEEDUP", b"GPS_TYPE"):
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
      machines[0].wait_until_succeeds("ss -tn state established '( dport = :5760 )' | grep -q 5760", timeout=120)
      machines[0].wait_until_succeeds("ss -tln '( sport = :5790 )' | grep -q 5790", timeout=60)
      # EKF needs sim GPS lock before arming; the battery's arm() retries, but
      # give the stack a generous head start on loaded runners.
      machines[0].succeed("python3 -c 'import indi_harness.sitl.baseline'")
      print(machines[0].execute("timeout 180 python3 /etc/s1-arm-probe.py 2>&1")[1])
      try:
          machines[0].succeed(
              "timeout 3600 python3 -m indi_harness.sitl.baseline"
              " --url tcp:127.0.0.1:5790"
              " --logs-dir /data/drone/ardusitl/logs"
              " --out /tmp/s1_baseline >&2"
          )
      except Exception:
          print("=== ardusitl journal (arm/EKF/GPS lines) ===")
          print(machines[0].execute("journalctl -u ardusitl --no-pager | grep -iE 'prearm|arm|ekf|gps|home' | tail -60")[1])
          print("=== log dir ===")
          print(machines[0].execute("find /data/drone -name '*.BIN' 2>/dev/null; ls -la /data/drone/ardusitl 2>/dev/null")[1])
          raise
      machines[0].succeed("test -s /tmp/s1_baseline/s1_baseline.json")
      machines[0].copy_from_vm("/tmp/s1_baseline/s1_baseline.json", "")
      print(machines[0].succeed("cat /tmp/s1_baseline/s1_baseline.json"))
    '';
}
