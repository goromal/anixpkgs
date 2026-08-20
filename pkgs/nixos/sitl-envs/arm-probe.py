import time
from pymavlink import mavutil

c = mavutil.mavlink_connection("tcp:127.0.0.1:5790")
c.wait_heartbeat(timeout=120)
print(f"probe: heartbeat sys={c.target_system} comp={c.target_component}", flush=True)
c.mav.request_data_stream_send(c.target_system, c.target_component,
    mavutil.mavlink.MAV_DATA_STREAM_ALL, 4, 1)
for p in (b"ARMING_CHECK", b"FS_THR_ENABLE", b"SIM_SPEEDUP", b"GPS_TYPE", b"CC_TYPE"):
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
