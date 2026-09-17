"""Stock-ArduPilot frame/sign gate for the JSON drag-rejection backend.

Flies STOCK ArduCopter (no custom controller) on the custom pysignals JSON
physics backend with drag OFF, and asserts that the EKF tracks commanded NED
motion with no N/E swap and no sign inversion -- i.e. the backend's state
mapping (position sign, velocity rotation, quaternion order) is frame-correct.

Sequence: GUIDED -> arm -> takeoff 10 m -> +N velocity -> +E velocity, each in
the LOCAL_NED frame. Writes a JSON verdict to --out and exits non-zero on
failure. Thin driver over the shared indi_harness.sitl.mavflight helpers.
"""
import argparse
import json
import os
import sys
import time

from indi_harness.sitl import mavflight


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", default="tcp:127.0.0.1:5790")
    ap.add_argument("--out", default="/tmp/drag_gate/flown.json")
    a = ap.parse_args()

    m = mavflight.connect(a.url)
    print(f"[gate] heartbeat sys={m.target_system} comp={m.target_component}", flush=True)
    if m.target_system == 0:
        _write(a.out, {"passed": False, "reason": "no valid heartbeat (target_system=0)"})
        return 4
    mavflight.request_data_stream(m, rate=5)

    print("[gate] settling GPS/EKF...", flush=True)
    gps_ok = mavflight.wait_gps(m, timeout=45)
    print(f"[gate] gps_ok={gps_ok}", flush=True)

    m.set_mode_apm("GUIDED")
    time.sleep(1)

    print("[gate] arming...", flush=True)
    armed = mavflight.arm_with_retry(m, timeout=120, verbose=True)
    print(f"[gate] armed={armed}", flush=True)
    if not armed:
        _write(a.out, {"passed": False, "reason": "could not arm"})
        return 2

    TARGET_ALT = 10.0
    print(f"[gate] takeoff to {TARGET_ALT} m...", flush=True)
    p = mavflight.takeoff(m, TARGET_ALT)
    p_to = mavflight.get_local_pos(m)
    settled = p is not None
    print(f"[gate] settled={settled} local_ned_after_takeoff={p_to}", flush=True)
    if not settled:
        _write(a.out, {"passed": False, "reason": "takeoff did not settle at altitude",
                       "local_ned": p_to})
        return 3

    # Velocity setpoints (LOCAL_NED): command a steady NED velocity, hold it long
    # enough for the position controller to accelerate, then measure net
    # displacement (a cleaner frame/sign probe than an absolute position target).
    mavflight.guided_move_ned(m, 0, 0, 0, "SETTLE", dur=3)
    mv_n, _ = mavflight.guided_move_ned(m, 3.0, 0.0, 0.0, "NORTH_VEL")
    mavflight.guided_move_ned(m, 0, 0, 0, "STOP", dur=4)
    mv_e, end_e = mavflight.guided_move_ned(m, 0.0, 3.0, 0.0, "EAST_VEL")

    checks = {
        "north_moves_north": mv_n[0] > 3.0,
        "north_dominates_east": abs(mv_n[0]) > abs(mv_n[1]),
        "east_moves_east": mv_e[1] > 3.0,
        "east_dominates_north": abs(mv_e[1]) > abs(mv_e[0]),
        "altitude_stable": -end_e[2] > 8.0,
    }
    passed = all(checks.values())
    verdict = {"passed": passed, "checks": checks,
               "north_delta": mv_n, "east_delta": mv_e,
               "takeoff_local_ned": p_to}
    _write(a.out, verdict)
    print(f"[gate] verdict={verdict}", flush=True)
    print("RESULT " + ("PASS" if passed else "FAIL"), flush=True)
    return 0 if passed else 1


def _write(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(obj, f, indent=2)


if __name__ == "__main__":
    sys.exit(main())
