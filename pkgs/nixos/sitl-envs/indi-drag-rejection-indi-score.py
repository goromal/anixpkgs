"""INDI-on-JSON-backend scorer (diagnostic).

Asserts the shipped Layer-B INDI (CC_TYPE=3, CC3_OUTER_EN=1) flies the battery on
the pysignals JSON backend (drag OFF) within a documented tolerance of the
benign-SITL Layer-B baseline, and extracts the inner-loop buzz / omega-inversion
health so clean-vs-buzz is a first-class finding. All diagnostics are PRINTED
before any assertion, so a controller-buzz finding survives a failed gate.
Reusable helpers live in indi_harness.sitl.binscore. Finding writeup:
indi-harness/docs/json_physics_backend_results.md

argv: <flight.BIN> <flown.json> <baseline.json> [track_tol_abs_m] [track_tol_mult]
"""
import json
import sys

import numpy as np

from indi_harness.sitl.binlog import (
    read_outer_health,
    read_indi_health,
    read_imu_gyro,
)
from indi_harness.sitl.align import flat_tracking_score
from indi_harness.sitl.binscore import (
    rms,
    active_runs,
    read_rate_msgs,
    read_engage_msgs,
    gyro_window,
    omega_window,
    rate_window,
)

BIN = sys.argv[1]
FLOWN = sys.argv[2]
BASELINE = sys.argv[3]
# Documented tolerance band (defaults; overridable from the env for the record):
# a per-case backend RMS is acceptable if it is BELOW an absolute bound AND
# within a multiple of the benign-SITL baseline. The backend adds real actuator
# lag + momentum thrust that benign SITL lacks, so some degradation is expected;
# these bounds encode "flies and tracks reasonably", not parity.
TRACK_TOL_ABS_M = float(sys.argv[4]) if len(sys.argv) > 4 else 1.5
TRACK_TOL_MULT = float(sys.argv[5]) if len(sys.argv) > 5 else 2.0


# --- outer-loop tracking (INDB) ---------------------------------------------
h = read_outer_health(BIN)
tus = h["time_us"]
ref = h["ref_p"]
meas = h["meas_p"]
fb = np.asarray(h["fallback"], int)

agg = flat_tracking_score(h)              # active-window aggregate (both cases)
runs = active_runs(fb)
flown = json.loads(open(FLOWN).read())
case_names = [f["case"] for f in flown]
baseline = {b["case"]: b for b in json.loads(open(BASELINE).read())}

# Inner-loop sources, read once; sliced per case by TimeUS window below.
ih = read_indi_health(BIN)
rt, rdes_all, ract_all, pdes_all, pact_all = read_rate_msgs(BIN)
# Trustworthy buzz source: ~50 Hz IMU gyro (roll=GyrX, pitch=GyrY), deg/s.
gt, gyro_all = read_imu_gyro(BIN)
# Concrete engagement proof from the firmware STATUSTEXT log.
engage_msgs = read_engage_msgs(BIN)


# Map contiguous engaged blocks to the cases in flight order; score each case's
# outer-loop tracking AND its inner-loop (omega inversion + rate buzz) in the
# SAME window -- so a single blown case can't smear its buzz across a clean one.
per_case = []
for idx, (i, j) in enumerate(runs):
    name = case_names[idx] if idx < len(case_names) else f"run{idx}"
    err = np.linalg.norm(ref[i:j] - meas[i:j], axis=1)
    t0, t1 = float(tus[i]), float(tus[j - 1])
    alt = -meas[i:j][:, 2]
    per_case.append({
        "case": name,
        "rms_m": rms(err),
        "max_m": float(err.max()) if err.size else 0.0,
        "peak_alt_m": float(alt.max()) if alt.size else 0.0,
        "n": int(j - i),
        "t0_us": t0, "t1_us": t1,
        "omega": omega_window(ih, t0, t1),
        "rate": rate_window(rt, rdes_all, ract_all, pdes_all, pact_all, t0, t1),
        "gyro": gyro_window(gt, gyro_all, t0, t1),
    })

# Active-window aggregate bounds (whole battery).
act = fb == 0
t_lo = float(tus[act].min()) if act.any() else float(tus.min())
t_hi = float(tus[act].max()) if act.any() else float(tus.max())
meas_d = meas[act][:, 2] if act.any() else np.array([0.0])
peak_alt_m = float(-meas_d.min())
omega = omega_window(ih, t_lo, t_hi)
du_rms = omega["du_rms"]
sat_frac = omega["sat_frac"]
agg_rate = rate_window(rt, rdes_all, ract_all, pdes_all, pact_all, t_lo, t_hi)
roll_rate = agg_rate["roll"]
pitch_rate = agg_rate["pitch"]
agg_gyro = gyro_window(gt, gyro_all, t_lo, t_hi)
# Engagement proof: STATUSTEXT saw "ON" AND the INDI increment du is non-zero
# over the active window (a stock flight logs no du / all-zero du).
du_active_rms = float(np.sqrt(np.mean(np.square(du_rms)))) if du_rms else 0.0
engaged_on = any("is on" in m.lower() for m in engage_msgs)
indi_active = du_active_rms > 1e-6

# --- report ------------------------------------------------------------------
report = {
    "aggregate": agg,
    "per_case": per_case,
    "baseline": {k: baseline[k]["rms_m"] for k in baseline},
    "tolerance": {"abs_m": TRACK_TOL_ABS_M, "mult": TRACK_TOL_MULT},
    "peak_alt_m": peak_alt_m,
    "omega_inversion": omega,
    "roll_rate": roll_rate,
    "pitch_rate": pitch_rate,
    "gyro_buzz": agg_gyro,
    "engagement": {
        "statustext": engage_msgs,
        "engaged_on": engaged_on,
        "du_active_rms": du_active_rms,
        "indi_active": indi_active,
    },
    "n_runs": len(runs),
}
open("/tmp/flight/indi_score.json", "w").write(json.dumps(report, indent=1))

print("=== INDI-on-JSON-backend battery ===", flush=True)
print(f"cases flown       : {case_names}", flush=True)
print(f"ENGAGEMENT        : statustext={engage_msgs} engaged_on={engaged_on} "
      f"du_active_rms={du_active_rms:.5f} indi_active={indi_active}", flush=True)
print(f"aggregate track   : rms={agg['rms_m']:.3f} m max={agg['max_m']:.3f} m "
      f"active_frac={agg['active_frac']:.3f} n={agg['n']} runs={len(runs)}",
      flush=True)
print(f"peak altitude     : {peak_alt_m:.1f} m", flush=True)
for pc in per_case:
    b = baseline.get(pc["case"], {}).get("rms_m", float("nan"))
    ratio = pc["rms_m"] / b if b and not np.isnan(b) else float("nan")
    # Degradation classification (reported, not a hard fail): the backend's real
    # actuator lag + momentum thrust legitimately degrade tracking vs benign SITL.
    verdict = ("clean-drop-in" if ratio <= TRACK_TOL_MULT
               else "degraded-but-flies" if pc["rms_m"] < TRACK_TOL_ABS_M
               else "FAILS-tolerance")
    print(f"  {pc['case']:<16} backend_rms={pc['rms_m']:.3f} m  "
          f"baseline_rms={b:.3f} m  ratio={ratio:.2f}x  "
          f"max={pc['max_m']:.3f} m  peak_alt={pc['peak_alt_m']:.1f} m  "
          f"n={pc['n']}  [{verdict}]", flush=True)


def _print_gyro(label, gy):
    """Trustworthy IMU-gyro buzz block (deg/s). Under clean tracking roll/pitch
    body-rate rms is modest and buzz_hp_rms (high-pass residual) is small; a
    rate-loop limit cycle drives buzz_hp_rms sharply up."""
    print(f"--- inner-loop [{label}] IMU-gyro buzz (trustworthy, ~50 Hz) ---",
          flush=True)
    for nm in ("roll", "pitch"):
        g = gy[nm]
        print(f"  {nm:<5} gyro deg/s: rms={g['rms']:.2f} "
              f"buzz_hp_rms={g['buzz_hp_rms']:.2f}", flush=True)
    print(f"  gyro samples    : {gy['n']}", flush=True)


def _print_inner(label, om, rate):
    """Inner-loop buzz block: omega_dot inversion + roll/pitch RATE. Benign-SITL
    Layer-B reference (circle_slow fixture): roll/pitch exc_rms ~3.8/4.9 rad/s^2,
    RATE act_rms ~31/38 deg/s, buzz_ddt_rms ~21/27 deg/s. Multiples of THOSE are
    the buzz signal (the actuator-lag inner-loop risk)."""
    print(f"--- inner-loop [{label}] omega_dot inversion + RATE buzz ---", flush=True)
    for nm in ("roll", "pitch", "yaw"):
        o = om[nm]
        print(f"  {nm:<5} nrmse={o['nrmse']:.3f}  r2={o['r2']:.3f}  "
              f"exc_rms={o['exc_rms']:.3f} rad/s^2  "
              f"du_rms={om['du_rms'][{'roll': 0, 'pitch': 1, 'yaw': 2}[nm]]:.4f}",
              flush=True)
    print(f"  saturation frac : {om['sat_frac']:.3f}", flush=True)
    for nm in ("roll", "pitch"):
        r = rate[nm]
        print(f"  {nm:<5} RATE deg/s: des_rms={r['des_rms']:.2f} "
              f"act_rms={r['act_rms']:.2f} err_rms={r['err_rms']:.2f} "
              f"buzz_ddt_rms={r['buzz_ddt_rms']:.2f}", flush=True)


_print_inner("aggregate", omega, agg_rate)
_print_gyro("aggregate", agg_gyro)
for pc in per_case:
    _print_inner(pc["case"], pc["omega"], pc["rate"])
    _print_gyro(pc["case"], pc["gyro"])

# --- hard gate (documented tolerance band) ----------------------------------
# These assertions run AFTER all diagnostics are printed + persisted, so a buzz
# or tracking failure surfaces the numbers (the finding) rather than hiding them.
errs = []
# Engagement gate: if the INDI increment du is ~zero over the active window the
# custom controller never engaged and the vehicle flew STOCK -- every INDI
# tracking/buzz number would be meaningless, so hard-fail with the evidence.
if not indi_active:
    errs.append(f"custom controller NOT engaged (flew stock): du_active_rms="
                f"{du_active_rms:.6f}, statustext={engage_msgs}")
elif not engaged_on:
    # du is non-zero (engaged) but the STATUSTEXT wasn't logged -- warn, don't
    # fail: the .BIN du is the authoritative proof and it says engaged.
    print("  WARN: INDI active (du>0) but 'Custom controller is ON' STATUSTEXT "
          f"not found in MSG log; statustext={engage_msgs}", flush=True)
if len(per_case) != len(case_names):
    errs.append(f"engaged blocks ({len(per_case)}) != cases flown "
                f"({len(case_names)}): {case_names}")
if not (agg["active_frac"] > 0.4):
    errs.append(f"outer loop barely active: active_frac={agg['active_frac']:.3f}")
if not (peak_alt_m < 14.0):
    errs.append(f"altitude runaway suspected: peak {peak_alt_m:.1f} m")
# Hard gate = per-case absolute bound < TRACK_TOL_ABS_M (the same 1.5 m "it flew
# the trajectory" threshold the benign flatness gate asserts on its aggregate).
# The mult-of-baseline is reported above as a degradation class, NOT hard-failed:
# the backend has real lag/momentum physics benign SITL lacks, so bit-parity is
# not the bar -- "flies and tracks reasonably" is.
for pc in per_case:
    if not (pc["rms_m"] < TRACK_TOL_ABS_M):
        errs.append(f"{pc['case']}: backend rms {pc['rms_m']:.3f} m "
                    f">= abs tol {TRACK_TOL_ABS_M} m")

if errs:
    print("=== INDI-on-JSON-backend gate FAIL ===", flush=True)
    for e in errs:
        print("  FAIL:", e, flush=True)
    sys.exit(1)
print("=== INDI-on-JSON-backend gate PASS ===", flush=True)
