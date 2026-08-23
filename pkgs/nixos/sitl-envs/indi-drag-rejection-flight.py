"""Stock-ArduPilot frame/sign gate for the JSON drag-rejection backend.

Flies STOCK ArduCopter (no custom controller) on the custom pysignals JSON
physics backend with drag OFF, and asserts that the EKF tracks commanded NED
motion with no N/E swap and no sign inversion -- i.e. the backend's state
mapping (position sign, velocity rotation, quaternion order) is frame-correct.

Sequence: GUIDED -> arm -> takeoff 10 m -> +5 m North -> +5 m East, each in the
LOCAL_NED frame. Writes a JSON verdict to --out and exits non-zero on failure.
"""
import argparse
import json
import sys
import time

from pymavlink import mavutil


def get_local_pos(m, timeout=3.0):
    # Return the FRESHEST LOCAL_POSITION_NED. We stream at high rate and send
    # setpoints in tight loops without reading, so the receive buffer backs up;
    # a single blocking recv_match returns the OLDEST queued sample, which lags
    # the true position by many seconds and makes a real move look like zero
    # displacement. Drain everything pending, then return the last one (falling
    # back to one blocking read if the buffer was momentarily empty).
    latest = None
    while True:
        msg = m.recv_match(type="LOCAL_POSITION_NED", blocking=False)
        if msg is None:
            break
        latest = msg
    if latest is None:
        latest = m.recv_match(type="LOCAL_POSITION_NED", blocking=True, timeout=timeout)
    return None if latest is None else (latest.x, latest.y, latest.z)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", default="tcp:127.0.0.1:5790")
    ap.add_argument("--out", default="/tmp/drag_gate/flown.json")
    a = ap.parse_args()

    m = mavutil.mavlink_connection(a.url)
    # Wait for a heartbeat that actually carries a nonzero autopilot system id.
    # A bare wait_heartbeat can return with target_system=0 (timeout, or a
    # heartbeat from a non-autopilot component), after which every command is
    # addressed to system 0 and arming silently never takes.
    t0 = time.time()
    while time.time() - t0 < 180:
        m.wait_heartbeat(timeout=10)
        if m.target_system != 0:
            break
    print(f"[gate] heartbeat sys={m.target_system} comp={m.target_component}", flush=True)
    if m.target_system == 0:
        _write(a.out, {"passed": False, "reason": "no valid heartbeat (target_system=0)"})
        return 4
    m.mav.request_data_stream_send(m.target_system, m.target_component,
                                   mavutil.mavlink.MAV_DATA_STREAM_ALL, 5, 1)

    # Brief GPS/EKF settle. Prearm (below) is the real readiness gate -- the
    # arm loop retries through prearm -- so this is only a short warm-up, not a
    # hard wait on a fix_type report (which routes inconsistently over 5790).
    print("[gate] settling GPS/EKF...", flush=True)
    t0 = time.time()
    gps_ok = False
    while time.time() - t0 < 45:
        g = m.recv_match(type="GPS_RAW_INT", blocking=True, timeout=2)
        if g and g.fix_type >= 3:
            gps_ok = True
        if gps_ok and time.time() - t0 > 15:
            break
    print(f"[gate] gps_ok={gps_ok} after {time.time()-t0:.0f}s", flush=True)

    m.set_mode_apm("GUIDED")
    time.sleep(1)

    # Arm (retry through prearm)
    print("[gate] arming...", flush=True)
    armed = False
    t0 = time.time()
    while time.time() - t0 < 120:
        m.mav.command_long_send(m.target_system, m.target_component,
                                mavutil.mavlink.MAV_CMD_COMPONENT_ARM_DISARM, 0,
                                1, 0, 0, 0, 0, 0, 0)
        hb = m.recv_match(type="HEARTBEAT", blocking=True, timeout=2)
        if hb and (hb.base_mode & mavutil.mavlink.MAV_MODE_FLAG_SAFETY_ARMED):
            armed = True
            break
        st = m.recv_match(type="STATUSTEXT", blocking=False)
        if st:
            print(f"[gate] STATUSTEXT: {st.text}", flush=True)
        time.sleep(2)
    print(f"[gate] armed={armed} after {time.time()-t0:.0f}s", flush=True)
    if not armed:
        _write(a.out, {"passed": False, "reason": "could not arm"})
        return 2

    # Takeoff to 10 m, then WAIT FOR THE ALTITUDE TO SETTLE before commanding
    # moves. The JSON backend has a high thrust-to-weight ratio, so ArduPilot's
    # guided-takeoff climb overshoots well past 10 m before the altitude loop
    # damps it back; commanding horizontal moves during that transient is
    # ignored (vehicle still in the takeoff climb). We wait until the vehicle is
    # near 10 m with small vertical speed for a sustained window -- a bounded,
    # damped transient, not a runaway.
    TARGET_ALT = 10.0
    print(f"[gate] takeoff to {TARGET_ALT} m...", flush=True)
    m.mav.command_long_send(m.target_system, m.target_component,
                            mavutil.mavlink.MAV_CMD_NAV_TAKEOFF, 0,
                            0, 0, 0, 0, 0, 0, TARGET_ALT)
    t0 = time.time()
    settled_since = None
    p = None
    while time.time() - t0 < 150:
        msg = m.recv_match(type="LOCAL_POSITION_NED", blocking=True, timeout=2)
        if msg is None:
            continue
        alt = -msg.z
        near = abs(alt - TARGET_ALT) < 2.5 and abs(msg.vz) < 0.4
        if near:
            settled_since = settled_since or time.time()
            if time.time() - settled_since > 5.0:
                p = (msg.x, msg.y, msg.z)
                break
        else:
            settled_since = None
    p_to = get_local_pos(m)
    settled = p is not None
    print(f"[gate] settled={settled} local_ned_after_takeoff={p_to}", flush=True)
    if not settled:
        _write(a.out, {"passed": False, "reason": "takeoff did not settle at altitude",
                       "local_ned": p_to})
        return 3

    # Velocity setpoints (LOCAL_NED): commanded a steady NED velocity and hold
    # it long enough for the position controller to accelerate, then measure the
    # net displacement. Velocity control is a cleaner frame/sign probe than an
    # absolute position target (which is interpreted in the EKF-origin frame and
    # takes many seconds to converge from a standstill).
    def command_vel(vn, ve, vd, label, dur=12):
        base = get_local_pos(m)
        t0 = time.time()
        while time.time() - t0 < dur:
            m.mav.set_position_target_local_ned_send(
                0, m.target_system, m.target_component,
                mavutil.mavlink.MAV_FRAME_LOCAL_NED,
                0b0000111111000111,  # velocity only
                0, 0, 0, vn, ve, vd, 0, 0, 0, 0, 0)
            time.sleep(0.1)
        end = get_local_pos(m)
        d = (end[0] - base[0], end[1] - base[1], end[2] - base[2])
        print(f"[gate] {label} base={base} end={end} "
              f"delta=(dN={d[0]:.2f},dE={d[1]:.2f},dD={d[2]:.2f})", flush=True)
        return d, end

    command_vel(0, 0, 0, "SETTLE", dur=3)
    mv_n, _ = command_vel(3.0, 0.0, 0.0, "NORTH_VEL")
    command_vel(0, 0, 0, "STOP", dur=4)
    mv_e, end_e = command_vel(0.0, 3.0, 0.0, "EAST_VEL")

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
    import os
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(obj, f, indent=2)


if __name__ == "__main__":
    sys.exit(main())
