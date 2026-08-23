# INDI drag-rejection demonstration -- S4 Phase 1 frame/sign gate.
#
# Boots ArduPilot SITL wired to the custom pysignals JSON physics backend
# (indi_harness.sitl.jsonsim) instead of ArduPilot's built-in multicopter model:
# SITL launches `arducopter --model=JSON:127.0.0.1`, connecting to the backend on
# UDP 9002. This gate proves the backend's FRAMES AND SIGNS ARE CORRECT by flying
# STOCK ArduCopter (no custom controller) with drag OFF and asserting the EKF
# tracks commanded NED motion with no N/E swap and no sign inversion -- the
# prerequisite for the later drag-on A/B rejection demo.
#
# Deliberately simpler than the flatness/rate SITL gates: no ROS2/DDS, no custom
# controller, no trajectory battery -- just stock GUIDED takeoff + NED velocity
# moves against the JSON backend.
#
# Run: nix-build pkgs/nixos/sitl-envs/indi-drag-rejection.nix
with import ../dependencies.nix;
let
  pkgs = (
    import (fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-${nixos-version}") {
      config = { };
      overlays = [ ];
    }
  );
  # indi-harness now propagates pysignals+geometry, so this env carries the
  # jsonsim physics backend and pymavlink for the flight script.
  jsonPy = anixpkgs.python313.withPackages (ps: [ ps.indi-harness ]);
in
pkgs.testers.runNixOSTest {
  name = "indi-drag-rejection";
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

        # The JSON backend's true hover throttle is ~0.30 (m*g vs its thrust
        # curve), below ArduPilot's default MOT_THST_HOVER (0.39). Tell the
        # altitude controller the real hover point and freeze hover learning so
        # its feedforward doesn't over-thrust; this tames (though does not fully
        # remove) the high-TWR takeoff overshoot before it damps to a stable
        # hover. The flight script additionally waits for the altitude to settle.
        services.ardupilot-sim.parameters = lib.mkAfter [
          "MOT_THST_HOVER 0.30"
          "MOT_HOVER_LEARN 0"
        ];

        # The custom physics backend. Must bind UDP 9002 before SITL connects;
        # ordered before ardusitl (SITL also retries/resends servos if the
        # backend is briefly late, but the test also waits for :9002 first).
        systemd.services.jsonsim-backend = {
          description = "pysignals JSON physics backend for ArduPilot SITL";
          before = [ "ardusitl.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "simple";
            # drag OFF: this gate is the clean frame/sign baseline (A of the A/B).
            ExecStart = "${jsonPy}/bin/python3 -m indi_harness.sitl.jsonsim --no-drag --port 9002";
            Restart = "on-failure";
            RestartSec = 2;
          };
        };

        # Shared GPS/EKF warm-up probe (same one the other SITL gates use).
        environment.etc."arm-probe.py".source = ./arm-probe.py;
        # Stock takeoff + NED-move frame/sign gate (writes a JSON verdict).
        environment.etc."indi-drag-rejection-flight.py".source = ./indi-drag-rejection-flight.py;
      };
  };
  testScript =
    { nodes, ... }:
    ''
      machines[0].wait_for_unit("default.target")
      # The JSON physics backend must be listening on UDP 9002 BEFORE SITL tries
      # to connect (note: UDP -> ss -u). wait_for_unit only confirms the unit
      # started; wait for the bound socket to be sure the server is serving.
      machines[0].wait_for_unit("jsonsim-backend.service")
      machines[0].wait_until_succeeds("ss -uln '( sport = :9002 )' | grep -q 9002", timeout=60)
      machines[0].wait_for_unit("ardusitl.service")
      machines[0].wait_for_unit("ardurouter.service")
      # SITL established its side of the mavlink link, and the router republishes
      # it on 5790 for the flight client.
      machines[0].wait_until_succeeds("ss -tn state established '( dport = :5760 )' | grep -q 5760", timeout=120)
      machines[0].wait_until_succeeds("ss -tln '( sport = :5790 )' | grep -q 5790", timeout=60)
      # The jsonsim module imports (pysignals+geometry propagated) inside the VM.
      machines[0].succeed("python3 -c 'import indi_harness.sitl.jsonsim.model'")

      # GPS/EKF warm-up (captured; surfaced only on failure).
      arm_probe = machines[0].execute("timeout 180 python3 /etc/arm-probe.py 2>&1")[1]

      # Fly the stock frame/sign gate: takeoff + NED velocity moves. Runs in the
      # foreground; writes /tmp/drag_gate/flown.json and exits non-zero on FAIL.
      try:
          print(machines[0].succeed(
              "timeout 900 python3 /etc/indi-drag-rejection-flight.py"
              " --url tcp:127.0.0.1:5790 --out /tmp/drag_gate/flown.json"))
      except Exception:
          print("=== arm/EKF/GPS probe ===")
          print(arm_probe)
          print("=== flown.json (if any) ===")
          print(machines[0].execute("cat /tmp/drag_gate/flown.json 2>/dev/null")[1])
          print("=== jsonsim-backend log ===")
          print(machines[0].execute("journalctl -u jsonsim-backend --no-pager | tail -30")[1])
          print("=== ardusitl journal (arm/EKF/GPS/home lines) ===")
          print(machines[0].execute("journalctl -u ardusitl --no-pager | grep -iE 'prearm|arm|ekf|gps|home|json' | grep -iv 'Loaded defaults' | tail -50")[1])
          raise

      # Export the flown verdict + the newest .BIN as artifacts.
      machines[0].succeed("test -s /tmp/drag_gate/flown.json")
      machines[0].copy_from_vm("/tmp/drag_gate/flown.json", "")
      machines[0].succeed("cp $(ls -t /data/drone/ardusitl/logs/*.BIN | head -1) /tmp/drag_gate/flight.BIN")
      machines[0].copy_from_vm("/tmp/drag_gate/flight.BIN", "")

      # Hard gate: stock EKF tracked the commanded NED moves with correct
      # frames/signs (no N/E swap, no sign inversion) and held altitude -- the
      # verdict's `passed` must be true.
      machines[0].succeed(
          "python3 -c \"import json,sys; "
          "v=json.load(open('/tmp/drag_gate/flown.json')); "
          "print('verdict:', json.dumps(v)); "
          "sys.exit(0 if v.get('passed') else 1)\"")
    '';
}
