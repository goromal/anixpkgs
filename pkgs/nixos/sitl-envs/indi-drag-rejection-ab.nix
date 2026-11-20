# One cell of the drag-rejection A/B: {stock, custom INDI} x {drag off, drag on}.
#
# Every cell uses the same firmware, parameters, takeoff and settled-handover
# check, and flies the same ramped fast-case references on the pysignals JSON
# backend. controller="custom" engages the measured-RPM INDI outer loop and
# flies the reference over DDS; controller="stock" never engages and streams the
# reference as GUIDED targets. drag toggles the backend's linear rotor drag.
# Each cell writes cell_score.json; `python3 -m indi_harness.sitl.drag_ab gap`
# compares the four.
#
# Run: nix-build pkgs/nixos/sitl-envs/indi-drag-rejection-ab.nix -A driver \
#        --argstr controller stock --arg drag true
{
  controller ? "custom",
  drag ? false,
}:
assert builtins.elem controller [
  "stock"
  "custom"
];
with import ../dependencies.nix;
let
  stock = controller == "stock";
  cases = "circle_fast,lemniscate_fast";

  pkgs = (
    import (fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-${nixos-version}") {
      config = { };
      overlays = [ ];
    }
  );
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

  # Benign-SITL flatness baselines for the flown cases
  # (indi-harness/baselines/indi_flatness_sitl.json), for the INDI diagnostics.
  baselineJson = pkgs.writeText "indi_flatness_baseline.json" (
    builtins.toJSON [
      {
        case = "circle_fast";
        rms_m = 0.4599;
      }
      {
        case = "lemniscate_fast";
        rms_m = 0.711;
      }
    ]
  );
in
pkgs.testers.runNixOSTest {
  name = "indi-drag-rejection-ab-${controller}-drag-${if drag then "on" else "off"}";
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

        services.ardupilot-sim.platform = "JSON:127.0.0.1";

        # Identical to indi-measured-rpm-tracking.nix in every cell; the stock
        # cells simply never engage the custom controller.
        services.ardupilot-sim.parameters = lib.mkAfter [
          "FRAME_TYPE 1"
          "MOT_THST_HOVER 0.30"
          "MOT_HOVER_LEARN 0"
          "MOT_THST_EXPO 0"
          "MOT_SPIN_ARM 0"
          "MOT_SPIN_MIN 0"
          "MOT_SPIN_MAX 1"
          "MOT_BAT_VOLT_MIN 0"
          "MOT_BAT_VOLT_MAX 0"
          "CC_TYPE 3"
          "CC_AXIS_MASK 7"
          "RC9_OPTION 109"
          "CC3_OMG_FILT 80"
          "CC3_G1_RP 500"
          "CC3_G1_YAW 28.8"
          "CC3_OUTER_EN 1"
          "CC3_B_THR_EN 0"
          "CC3_B_ACC_FILT 8"
          "CC3_USE_RPM 1"
          "CC3_G2_YAW 0"
        ];

        systemd.services.jsonsim-backend = {
          description = "pysignals JSON physics backend for ArduPilot SITL";
          before = [ "ardusitl.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "simple";
            ExecStart = "${indiPy}/bin/python3 -m indi_harness.sitl.jsonsim ${
              if drag then "--drag" else "--no-drag"
            } --port 9002";
            Restart = "on-failure";
            RestartSec = 2;
          };
        };

        environment.etc."arm-probe.py".source = ./arm-probe.py;
        environment.etc."indi-measured-rpm-tracking-score.py".source =
          ./indi-measured-rpm-tracking-score.py;
        environment.etc."indi_flatness_baseline.json".source = baselineJson;
      };
  };
  testScript =
    { nodes, ... }:
    ''
      machines[0].wait_for_unit("default.target")
      machines[0].wait_for_unit("jsonsim-backend.service")
      machines[0].wait_until_succeeds("ss -uln '( sport = :9002 )' | grep -q 9002", timeout=60)
      machines[0].wait_for_unit("ardusitl.service")
      machines[0].wait_for_unit("ardurouter.service")
      machines[0].wait_for_unit("microxrce-agent.service")
      machines[0].wait_until_succeeds("ss -tn state established '( dport = :5760 )' | grep -q 5760", timeout=120)
      machines[0].wait_until_succeeds("ss -tln '( sport = :5790 )' | grep -q 5790", timeout=60)
      machines[0].wait_until_succeeds("timeout 60 ros2 topic list > /tmp/rostopics 2>/dev/null || true; grep -q '^/ap/pose' /tmp/rostopics", timeout=600)
      machines[0].wait_until_succeeds("timeout 60 ros2 topic list > /tmp/rostopics 2>/dev/null || true; grep -q '^/ap/clock' /tmp/rostopics", timeout=600)
      backend = machines[0].succeed("journalctl -u jsonsim-backend --no-pager | grep 'drag_on=' | tail -1")
      print(backend)
      assert "drag_on=${if drag then "True" else "False"}" in backend, backend

      arm_probe_rc, arm_probe = machines[0].execute(
          "timeout 180 python3 /etc/arm-probe.py 2>&1")
      assert arm_probe_rc == 0, f"arm probe failed to leave SITL disarmed:\n{arm_probe}"

      machines[0].execute("mkdir -p /tmp/flight; rm -f /tmp/trajectory_ready")
      machines[0].execute(
          "(timeout 600 python3 -m indi_harness.sitl.baseline_outer"
          " --url tcp:127.0.0.1:5790 --out /tmp/flight --engage-rc 9"
          " --cases ${cases}"
          " ${if stock then "--stock" else "--ready-file /tmp/trajectory_ready"}"
          " >/tmp/runner.log 2>&1 &"
          " echo $! >/tmp/runner.pid)"
      )
      try:
          if not ${if stock then "True" else "False"}:
              machines[0].wait_until_succeeds(
                  "test -s /tmp/trajectory_ready || "
                  "! kill -0 $(cat /tmp/runner.pid) 2>/dev/null", timeout=300)
              machines[0].succeed("test -s /tmp/trajectory_ready")
              machines[0].execute(
                  "(PYTHONPATH=${indiSitePackages} ${rosPy}/bin/python3"
                  " -m indi_harness.offboard.traj_server --ready-file /tmp/trajectory_ready"
                  " >/tmp/traj.log 2>&1 & echo $! >/tmp/traj.pid)"
              )
          machines[0].succeed(
              "PID=$(cat /tmp/runner.pid); for i in $(seq 1 600); do "
              "kill -0 $PID 2>/dev/null || break; sleep 1; done; "
              "test -s /tmp/flight/indi_flatness_flown.json"
          )
      except Exception:
          print("=== runner.log ==="); print(machines[0].execute("cat /tmp/runner.log 2>/dev/null | tail -40")[1])
          print("=== traj.log ==="); print(machines[0].execute("cat /tmp/traj.log 2>/dev/null | tail -40")[1])
          print("=== jsonsim-backend log ==="); print(machines[0].execute("journalctl -u jsonsim-backend --no-pager | tail -30")[1])
          raise
      finally:
          machines[0].execute("kill -INT $(cat /tmp/traj.pid) 2>/dev/null || true; sleep 1")
          machines[0].execute(
              "cp $(ls -t /data/drone/ardusitl/logs/*.BIN | head -1)"
              " /tmp/flight/flight.BIN 2>/dev/null || true;"
              " cp /tmp/runner.log /tmp/traj.log /tmp/flight/ 2>/dev/null || true")
          for artifact in ["flight.BIN", "handover.json", "runner.log", "traj.log",
                           "indi_flatness_flown.json"]:
              rc, _ = machines[0].execute(f"test -s /tmp/flight/{artifact}")
              if rc == 0:
                  machines[0].copy_from_vm(f"/tmp/flight/{artifact}", "")

      print(machines[0].succeed(
          "python3 -m indi_harness.sitl.drag_ab score --controller ${controller}"
          " /tmp/flight/flight.BIN /tmp/flight/indi_flatness_flown.json"
          " --out /tmp/flight/cell_score.json 2>&1"))
      machines[0].copy_from_vm("/tmp/flight/cell_score.json", "")

      if not ${if stock then "True" else "False"}:
          # Inner-loop health (saturation, omega-dot inversion, gyro buzz) for
          # the INDI cells. Reported, not gated: drag-on tracking is not
          # expected to match the benign baseline.
          rc, out = machines[0].execute(
              "python3 /etc/indi-measured-rpm-tracking-score.py"
              " /tmp/flight/flight.BIN /tmp/flight/indi_flatness_flown.json"
              " /etc/indi_flatness_baseline.json 1.5 0.02 0.6 2>&1")
          print(out)
          print(f"INDI health score rc={rc}")
          rc, _ = machines[0].execute("test -s /tmp/flight/indi_score.json")
          if rc == 0:
              machines[0].copy_from_vm("/tmp/flight/indi_score.json", "")
    '';
}
