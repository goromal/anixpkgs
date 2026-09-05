"""GPS/EKF/arm warm-up probe: connect, dump a few relevant params, then arm
through prearm (printing STATUSTEXT reasons) and disarm. Diagnostic only --
captured by the SITL gates and surfaced on failure. Thin driver over the shared
indi_harness.sitl.mavflight helpers."""
from indi_harness.sitl import mavflight

m = mavflight.connect("tcp:127.0.0.1:5790")
print(f"probe: heartbeat sys={m.target_system} comp={m.target_component}", flush=True)
mavflight.request_data_stream(m, rate=4)

# Request a few params relevant to arming, then print them as they arrive.
for p in (b"ARMING_CHECK", b"FS_THR_ENABLE", b"SIM_SPEEDUP", b"GPS_TYPE", b"CC_TYPE"):
    m.mav.param_request_read_send(m.target_system, m.target_component, p, -1)
for _ in range(20):
    pv = m.recv_match(type="PARAM_VALUE", blocking=True, timeout=1)
    if pv is None:
        break
    print(f"probe: PARAM {pv.param_id} = {pv.param_value}", flush=True)

gps_ok = mavflight.wait_gps(m, timeout=45)
print(f"probe: gps_ok={gps_ok}", flush=True)

armed = mavflight.arm_with_retry(m, timeout=90, verbose=True)
print(f"probe: armed={armed}", flush=True)
if armed:
    mavflight.disarm(m, force=True)
print("probe: done", flush=True)
