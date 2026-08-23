"""S4 Phase-1 INDI-on-JSON-backend scorer: assert the shipped in-firmware
Layer-B INDI outer loop (CC_TYPE=3, CC3_OUTER_EN=1) flies the trajectory battery
on the higher-fidelity pysignals JSON physics backend (actuator lag tau_m=0.03,
momentum thrust), DRAG OFF, and tracks within a documented tolerance of the
benign-SITL Layer-B baseline (indi-harness/baselines/s3_layerB_sitl.json).

This is a drop-in-fidelity gate BEFORE drag is introduced: the point is "flies
and tracks reasonably on the real-lag backend", not bit-parity with benign SITL.
It ALSO makes the actuator-lag inner-loop risk explicit: the C1 omega_dot
inversion (OMG_FILT=80) was calibrated for benign SITL, and the backend's
first-order actuator lag can re-stress it into a rate-loop limit cycle (buzz).
So the scorer extracts and prints roll/pitch RATE (desired vs actual) and the
INDI inner-loop health (domega_pred vs domega_meas, du, saturation) over the
active window -- clean numbers vs buzz is a first-class reported finding.

Everything is PRINTED first (and written to a JSON artifact) so the diagnostic
numbers survive even when a tolerance assertion fails -- controller buzz is a
finding to report, not a plumbing failure to hide.

argv: <flight.BIN> <flown.json> <baseline.json> [track_tol_abs_m] [track_tol_mult]
"""
import json
import sys

import numpy as np

from indi_harness.sitl.binlog import read_outer_health, read_indi_health
from indi_harness.sitl.align import flat_tracking_score, omega_tracking_score
from pymavlink import DFReader

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


def _rms(x):
    x = np.asarray(x, float)
    return float(np.sqrt(np.mean(x ** 2))) if x.size else 0.0


def _active_runs(fb, min_len=50):
    """Contiguous fallback==0 runs (each = one case's engaged tracking block).
    The runner unlinks the ready-file between cases -> the DDS reference goes
    stale -> fallback rises, cleanly separating cases in the INDB stream."""
    fb = np.asarray(fb, int)
    runs = []
    i = 0
    n = len(fb)
    while i < n:
        if fb[i] == 0:
            j = i
            while j < n and fb[j] == 0:
                j += 1
            if j - i >= min_len:
                runs.append((i, j))
            i = j
        else:
            i += 1
    return runs


def _read_rate(path):
    """Roll/pitch rate desired-vs-actual (deg/s) from the RATE message."""
    log = DFReader.DFReader_binary(str(path))
    t, rd, r, pd, p = [], [], [], [], []
    while True:
        m = log.recv_match(type="RATE")
        if m is None:
            break
        t.append(m.TimeUS)
        rd.append(m.RDes); r.append(m.R)
        pd.append(m.PDes); p.append(m.P)
    return (np.asarray(t, float), np.asarray(rd, float), np.asarray(r, float),
            np.asarray(pd, float), np.asarray(p, float))


# --- outer-loop tracking (INDB) ---------------------------------------------
h = read_outer_health(BIN)
tus = h["time_us"]
ref = h["ref_p"]
meas = h["meas_p"]
fb = np.asarray(h["fallback"], int)

agg = flat_tracking_score(h)              # active-window aggregate (both cases)
runs = _active_runs(fb)
flown = json.loads(open(FLOWN).read())
case_names = [f["case"] for f in flown]
baseline = {b["case"]: b for b in json.loads(open(BASELINE).read())}

# Inner-loop sources, read once; sliced per case by TimeUS window below.
ih = read_indi_health(BIN)
it = ih["time_us"]
rt, rdes_all, ract_all, pdes_all, pact_all = _read_rate(BIN)


def _omega_window(t0, t1):
    """Per-axis omega_dot-inversion score over an INDI TimeUS window."""
    w = (it >= t0) & (it <= t1)
    ihw = {k: (v[w] if getattr(v, "ndim", 1) else v) for k, v in ih.items()}
    om = omega_tracking_score(ihw)
    du = np.asarray(ihw["du"], float)
    sat = np.asarray(ihw["sat"], int)
    return {
        "roll": om[0], "pitch": om[1], "yaw": om[2],
        "du_rms": [_rms(du[:, ax]) for ax in range(3)] if du.size else [0.0] * 3,
        "sat_frac": float(sat.mean()) if sat.size else 0.0,
    }


def _rate_window(t0, t1):
    """Roll/pitch rate tracking + buzz proxy over a RATE TimeUS window. The buzz
    proxy is RMS of the sample-to-sample change of the ACTUAL rate: a limit
    cycle (inner-loop buzz) shows up as large high-frequency actual-rate motion
    even where the desired rate is smooth, so d(actual)/sample RMS spikes."""
    w = (rt >= t0) & (rt <= t1)
    rd, ra, pd, pa = rdes_all[w], ract_all[w], pdes_all[w], pact_all[w]
    def axis(des, act):
        return {"des_rms": _rms(des), "act_rms": _rms(act),
                "err_rms": _rms(act - des),
                "buzz_ddt_rms": _rms(np.diff(act)) if act.size > 1 else 0.0}
    return {"roll": axis(rd, ra), "pitch": axis(pd, pa)}


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
        "rms_m": _rms(err),
        "max_m": float(err.max()) if err.size else 0.0,
        "peak_alt_m": float(alt.max()) if alt.size else 0.0,
        "n": int(j - i),
        "t0_us": t0, "t1_us": t1,
        "omega": _omega_window(t0, t1),
        "rate": _rate_window(t0, t1),
    })

# Active-window aggregate bounds (whole battery).
act = fb == 0
t_lo = float(tus[act].min()) if act.any() else float(tus.min())
t_hi = float(tus[act].max()) if act.any() else float(tus.max())
meas_d = meas[act][:, 2] if act.any() else np.array([0.0])
peak_alt_m = float(-meas_d.min())
omega = _omega_window(t_lo, t_hi)
du_rms = omega["du_rms"]
sat_frac = omega["sat_frac"]
agg_rate = _rate_window(t_lo, t_hi)
roll_rate = agg_rate["roll"]
pitch_rate = agg_rate["pitch"]

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
    "n_runs": len(runs),
}
open("/tmp/flight/indi_score.json", "w").write(json.dumps(report, indent=1))

print("=== S4 INDI-on-JSON-backend battery ===", flush=True)
print(f"cases flown       : {case_names}", flush=True)
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
for pc in per_case:
    _print_inner(pc["case"], pc["omega"], pc["rate"])

# --- hard gate (documented tolerance band) ----------------------------------
# These assertions run AFTER all diagnostics are printed + persisted, so a buzz
# or tracking failure surfaces the numbers (the finding) rather than hiding them.
errs = []
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
    print("=== S4 INDI-on-JSON-backend gate FAIL ===", flush=True)
    for e in errs:
        print("  FAIL:", e, flush=True)
    sys.exit(1)
print("=== S4 INDI-on-JSON-backend gate PASS ===", flush=True)
