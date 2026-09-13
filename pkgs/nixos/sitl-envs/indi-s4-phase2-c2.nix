# INDI C2 "measured actuator state" trajectory acceptance experiment.
# NOT a green CI gate until the original tracking/buzz thresholds pass.
#
# Flies the two-case battery (circle_slow, lemniscate_fast) over the pysignals
# JSON backend (--no-drag) with CC3_USE_RPM=1 -- the C2 measured-actuator-state
# INDI path (u0 reconstructed in normalized mixer units from mechanical RPM,
# fed into the C1
# rate loop). G2 OFF, OMG_FILT at the shipped 80.
#
# September audit: the August failure did not establish structural instability.
# The old yaw effectiveness (1000) was ~35x the normalized plant value (28.8),
# and INDC Cx is current PID, not previous custom output. Small attitude flights
# now pass with corrected units; this larger DDS battery still needs validation.
# Current handoff: indi-harness/docs/2026-09-12-controller-audit.md.
#
# Preserve the original acceptance thresholds; do not loosen them to get green.
# Run with dependencies.nix local-build=true to test this checkout's lock pins.
# Run: nix-build pkgs/nixos/sitl-envs/indi-s4-phase2-c2.nix
with import ../dependencies.nix;
let
  # CC3_OMG_FILT (Hz): hardcoded at the shipped default. C2 (measured actuator
  # state) must close the buzz WITHOUT the omg160 filter crutch -- that is the
  # point of this gate.
  omgFilt = 80;
  # CC3_B_ACC_FILT (Hz): outer-loop specific-force / thrust-state phase-margin
  # cutoff; 8 is the firmware default and the swept-stable value the benign
  # flatness gate flies at.
  accFilt = 8;

  # Buzz-closes thresholds (provisional; calibrate-then-freeze after first clean
  # run -- see indi_harness.buzz_score.score for the exact per-criterion math).
  buzzTol = "1.5"; # track_rms <= benign_rms * buzzTol
  satTol = "0.02"; # saturation fraction ceiling
  nrmseTol = "0.6"; # omega-dot inversion NRMSE ceiling (Phase-1 buzz was ~1.5)

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

  # Benign-SITL Layer-B baseline rows for the two flown cases (from
  # indi-harness/baselines/s3_layerB_sitl.json). Embedded so the env is
  # self-contained (the baselines/ dir is not shipped in site-packages).
  baselineJson = pkgs.writeText "s3_layerB_baseline.json" (
    builtins.toJSON [
      {
        case = "circle_slow";
        rms_m = 0.4849;
      }
      {
        case = "lemniscate_fast";
        rms_m = 0.711;
      }
    ]
  );
in
pkgs.testers.runNixOSTest {
  name = "indi-s4-phase2-c2";
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

        # Point SITL's --model at the JSON backend instead of the built-in quad.
        services.ardupilot-sim.platform = "JSON:127.0.0.1";

        services.ardupilot-sim.parameters = lib.mkAfter [
          # JSON backend's true hover throttle (~0.30) is below ArduPilot's
          # default; tell the (stock, since CC3_B_THR_EN=0) altitude controller
          # the real hover point and freeze hover learning so its feedforward
          # doesn't over-thrust the high-TWR takeoff (mirrors the stock gate).
          "MOT_THST_HOVER 0.30"
          "MOT_HOVER_LEARN 0"
          # Linear command-to-Omega^2 map required by the normalized G1 seed.
          "MOT_THST_EXPO 0"
          "MOT_SPIN_ARM 0"
          "MOT_SPIN_MIN 0"
          "MOT_SPIN_MAX 1"
          "MOT_BAT_VOLT_MIN 0"
          "MOT_BAT_VOLT_MAX 0"
          # Shipped Layer-B INDI config (identical to indi-flatness-outer-loop):
          # INDI on all axes, RC9 -> CUSTOM_CONTROLLER (109), inner rate loop
          # tuned for angular-accel inversion (OMG_FILT=${toString omgFilt}, G1_RP 500),
          # flatness outer loop enabled, collective left to the stock altitude
          # controller.
          "CC_TYPE 3"
          "CC_AXIS_MASK 7"
          "RC9_OPTION 109"
          "CC3_OMG_FILT ${toString omgFilt}"
          "CC3_G1_RP 500"
          "CC3_G1_YAW 28.8"
          "CC3_OUTER_EN 1"
          "CC3_B_THR_EN 0"
          "CC3_B_ACC_FILT ${toString accFilt}"
          # C2 measured-actuator-state path: the fix under test. G2 (rotor-inertia
          # yaw reaction) stays OFF for this first flight to isolate whether
          # measured actuator state alone closes the roll/pitch buzz.
          "CC3_USE_RPM 1"
          "CC3_G2_YAW 0"
        ];

        # The custom physics backend, drag OFF (the clean drop-in baseline before
        # the drag-on A/B). Must bind UDP 9002 before SITL connects.
        systemd.services.jsonsim-backend = {
          description = "pysignals JSON physics backend for ArduPilot SITL";
          before = [ "ardusitl.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "simple";
            ExecStart = "${indiPy}/bin/python3 -m indi_harness.sitl.jsonsim --no-drag --port 9002";
            Restart = "on-failure";
            RestartSec = 2;
          };
        };

        # Shared GPS/EKF warm-up probe (same one the other SITL gates use).
        environment.etc."arm-probe.py".source = ./arm-probe.py;
        # C2 buzz-closes battery scorer (tracking + omega-inversion + rate buzz +
        # measured-RPM engagement proof).
        environment.etc."indi-s4-phase2-c2-score.py".source = ./indi-s4-phase2-c2-score.py;
        environment.etc."s3_layerB_baseline.json".source = baselineJson;
      };
  };
  testScript =
    { nodes, ... }:
    ''
      machines[0].wait_for_unit("default.target")
      # The JSON physics backend must be listening on UDP 9002 BEFORE SITL tries
      # to connect (note: UDP -> ss -u).
      machines[0].wait_for_unit("jsonsim-backend.service")
      machines[0].wait_until_succeeds("ss -uln '( sport = :9002 )' | grep -q 9002", timeout=60)
      machines[0].wait_for_unit("ardusitl.service")
      machines[0].wait_for_unit("ardurouter.service")
      machines[0].wait_for_unit("microxrce-agent.service")
      machines[0].wait_until_succeeds("ss -tn state established '( dport = :5760 )' | grep -q 5760", timeout=120)
      machines[0].wait_until_succeeds("ss -tln '( sport = :5790 )' | grep -q 5790", timeout=60)
      # Capture-then-grep (no pipe): grep -q on a live 'ros2 topic list' pipe
      # closes it on first match -> SIGPIPE -> under pipefail the poll returns
      # 141 even on a match and never succeeds. Write to a file first.
      machines[0].wait_until_succeeds("timeout 60 ros2 topic list > /tmp/rostopics 2>/dev/null || true; grep -q '^/ap/pose' /tmp/rostopics", timeout=600)
      machines[0].wait_until_succeeds("timeout 60 ros2 topic list > /tmp/rostopics 2>/dev/null || true; grep -q '^/ap/clock' /tmp/rostopics", timeout=600)
      machines[0].succeed("python3 -c 'import indi_harness.sitl.baseline_outer'")
      # The jsonsim module imports (pysignals+geometry propagated) inside the VM.
      machines[0].succeed("python3 -c 'import indi_harness.sitl.jsonsim.model'")

      # GPS/EKF warm-up (captured; surfaced only on failure).
      arm_probe = machines[0].execute("timeout 180 python3 /etc/arm-probe.py 2>&1")[1]

      # Fly the two-case battery (circle_slow + lemniscate_fast) with the
      # in-firmware INDI outer loop, DDS-driven by traj_server. The runner takes
      # off + engages once, then holds case-by-case writing {case,origin} to
      # /tmp/lb_ready; traj_server (battery mode) follows the ready-file and
      # stops between cases -> DDS-staleness fallback at the case boundary.
      machines[0].execute("mkdir -p /tmp/flight; rm -f /tmp/lb_ready")
      machines[0].execute(
          "(timeout 600 python3 -m indi_harness.sitl.baseline_outer"
          " --url tcp:127.0.0.1:5790 --out /tmp/flight --engage-rc 9"
          " --ready-file /tmp/lb_ready --cases circle_slow,lemniscate_fast"
          " >/tmp/runner.log 2>&1 &"
          " echo $! >/tmp/runner.pid)"
      )
      try:
          machines[0].wait_for_file("/tmp/lb_ready", timeout=300)
          machines[0].execute(
              "(PYTHONPATH=${indiSitePackages} ${rosPy}/bin/python3"
              " -m indi_harness.offboard.traj_server --ready-file /tmp/lb_ready"
              " >/tmp/traj.log 2>&1 & echo $! >/tmp/traj.pid)"
          )
          machines[0].succeed(
              "PID=$(cat /tmp/runner.pid); for i in $(seq 1 600); do "
              "kill -0 $PID 2>/dev/null || break; sleep 1; done; "
              "test -s /tmp/flight/s3_layerB_flown.json"
          )
      except Exception:
          print("=== runner.log ==="); print(machines[0].execute("cat /tmp/runner.log 2>/dev/null | tail -40")[1])
          print("=== traj.log ==="); print(machines[0].execute("cat /tmp/traj.log 2>/dev/null | tail -40")[1])
          print("=== arm probe ==="); print(arm_probe)
          print("=== jsonsim-backend log ==="); print(machines[0].execute("journalctl -u jsonsim-backend --no-pager | tail -30")[1])
          print("=== ardusitl journal ==="); print(machines[0].execute("journalctl -u ardusitl --no-pager | grep -iE 'prearm|arm|ekf|gps|home|custom|json' | grep -iv 'Loaded defaults' | tail -40")[1])
          raise
      finally:
          machines[0].execute("kill -INT $(cat /tmp/traj.pid) 2>/dev/null || true; sleep 1")

      # Export the newest .BIN (outer + inner loop health source of truth).
      machines[0].succeed("cp $(ls -t /data/drone/ardusitl/logs/*.BIN | head -1) /tmp/flight/flight.BIN")
      machines[0].copy_from_vm("/tmp/flight/flight.BIN", "")
      machines[0].copy_from_vm("/tmp/flight/s3_layerB_flown.json", "")

      # Score: run via execute() so ALL diagnostic numbers (tracking, omega
      # inversion, rate buzz, INDC measured-RPM health) print into the build log
      # even when a buzz-closes assertion fails -- controller buzz is a finding
      # to surface, not to hide.
      rc, out = machines[0].execute(
          "python3 /etc/indi-s4-phase2-c2-score.py"
          " /tmp/flight/flight.BIN /tmp/flight/s3_layerB_flown.json"
          " /etc/s3_layerB_baseline.json ${buzzTol} ${satTol} ${nrmseTol} 2>&1")
      print(out)
      machines[0].execute("cp /tmp/flight/indi_score.json /tmp/flight/ 2>/dev/null || true")
      machines[0].copy_from_vm("/tmp/flight/indi_score.json", "")
      assert rc == 0, f"C2 buzz-closes gate failed (rc={rc}); see score output above"
    '';
}
