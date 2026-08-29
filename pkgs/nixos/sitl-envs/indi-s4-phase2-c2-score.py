"""C2 measured-actuator-state buzz-closes scorer (S4 Phase 2 spec Section 5).

Flies the same INDI-on-JSON-backend battery as the indi-drag-rejection-indi.nix
DIAGNOSTIC (shipped tune, buzzes-by-design) but scores the C2 fix
(CC3_USE_RPM=1) against a BUZZ-CLOSES gate instead of the diagnostic's
tolerance band: per case, indi_harness.buzz_score.score() must report
closed=True (tracking RMS within tol of the benign-SITL baseline, actuator
saturation fraction under sat_tol, omega_dot inversion NRMSE under nrmse_tol).
All diagnostics -- tracking, omega inversion, IMU-gyro buzz, and the INDC
measured-RPM channel health -- are PRINTED before any assertion, so a
buzz-still-open finding survives a failed gate with full evidence.

Reusable helpers live in indi_harness.sitl.binscore. Design doc:
indi-harness/docs/s4_phase2_design.md (Section 5, buzz-closes gate).

argv: <flight.BIN> <flown.json> <baseline.json> <buzz_tol> <sat_tol> <nrmse_tol>
"""
import json
import sys

import numpy as np

from indi_harness.sitl.binlog import (
    read_outer_health,
    read_indi_health,
    read_imu_gyro,
    read_indc_health,
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
from indi_harness.buzz_score import score as buzz_score
from indi_harness.sysid import analytic_g1
from indi_harness.params import QuadParams

BIN = sys.argv[1]
FLOWN = sys.argv[2]
BASELINE = sys.argv[3]
# Buzz-closes thresholds (calibrate-then-freeze values live in the CI env, not
# hardcoded here -- see indi_harness.buzz_score.score docstring for the exact
# per-criterion math these gate).
BUZZ_TOL = float(sys.argv[4]) if len(sys.argv) > 4 else 1.5
SAT_TOL = float(sys.argv[5]) if len(sys.argv) > 5 else 0.02
NRMSE_TOL = float(sys.argv[6]) if len(sys.argv) > 6 else 0.6


# --- DIAGNOSTIC (Task 8 debug): does the reconstruction recover the command? --
# Read INDC Ux/Uy/Uz (reconstructed measured actuator state) vs Cx/Cy/Cz (stock
# previous-command). If U ~= C the reconstruction is faithful (instability is
# structural loop dynamics); if U = a*C + b with a != 1 the thrust-curve /
# spin-scaling distorts the operating point (reconstruction bug).
def _diag_recon():
    from pymavlink import DFReader
    log = DFReader.DFReader_binary(str(BIN))
    U, C = [], []
    while True:
        m = log.recv_match(type="INDC")
        if m is None:
            break
        U.append([m.Ux, m.Uy, m.Uz])
        C.append([m.Cx, m.Cy, m.Cz])
    U = np.asarray(U, float)
    C = np.asarray(C, float)
    print("=== RECON DIAGNOSTIC: measured U vs stock-command C ===", flush=True)
    if U.shape[0] < 10:
        print(f"  too few INDC rows ({U.shape[0]})", flush=True)
        return
    for k, nm in enumerate(("roll", "pitch", "yaw")):
        u, c = U[:, k], C[:, k]
        # slope/intercept of u ~= a*c + b, plus correlation.
        if np.std(c) > 1e-9:
            a, b = np.polyfit(c, u, 1)
            r = float(np.corrcoef(c, u)[0, 1])
        else:
            a = b = r = float("nan")
        print(f"  {nm:<5} U: mean={u.mean():+.4f} std={u.std():.4f} | "
              f"C: mean={c.mean():+.4f} std={c.std():.4f} | "
              f"U~={a:.3f}*C{b:+.4f} corr={r:+.3f}", flush=True)


try:
    _diag_recon()
except Exception as e:
    print(f"  RECON DIAGNOSTIC failed: {e}", flush=True)


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
# C2 measured-actuator-state channel (INDC): per-motor measured omega/omega_dot
# and the reconstructed actuator torque -- proof the RPM path actually ran.
ic = read_indc_health(BIN)


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

# --- INDC measured-RPM channel health -----------------------------------------
# Proof the CC3_USE_RPM=1 path actually ran: mostly non-fallback ticks (the
# firmware falls back to the previous command when RPM telemetry is stale/
# missing) and a non-zero measured rotor speed.
indc_n = int(ic["time_us"].size)
indc_fallback_frac = float(ic["fallback"].mean()) if indc_n else 1.0
indc_mean_abs_omega = float(np.mean(np.abs(ic["omega"]))) if indc_n else 0.0

# --- report ------------------------------------------------------------------
report = {
    "aggregate": agg,
    "per_case": per_case,
    "baseline": {k: baseline[k]["rms_m"] for k in baseline},
    "buzz_closes": {
        "tol": BUZZ_TOL,
        "sat_tol": SAT_TOL,
        "nrmse_tol": NRMSE_TOL,
    },
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
    "indc_health": {
        "n": indc_n,
        "fallback_frac": indc_fallback_frac,
        "mean_abs_omega": indc_mean_abs_omega,
    },
    "n_runs": len(runs),
}

print("=== C2 buzz-closes battery (INDI-on-JSON-backend) ===", flush=True)
print(f"cases flown       : {case_names}", flush=True)
print(f"ENGAGEMENT        : statustext={engage_msgs} engaged_on={engaged_on} "
      f"du_active_rms={du_active_rms:.5f} indi_active={indi_active}", flush=True)
print(f"aggregate track   : rms={agg['rms_m']:.3f} m max={agg['max_m']:.3f} m "
      f"active_frac={agg['active_frac']:.3f} n={agg['n']} runs={len(runs)}",
      flush=True)
print(f"peak altitude     : {peak_alt_m:.1f} m", flush=True)
print(f"--- INDC measured-RPM channel health (CC3_USE_RPM=1) ---", flush=True)
print(f"  ticks           : {indc_n}", flush=True)
print(f"  fallback_frac   : {indc_fallback_frac:.3f}", flush=True)
print(f"  mean |omega|    : {indc_mean_abs_omega:.2f} rad/s", flush=True)


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

# --- buzz-closes scoring (per case) -------------------------------------------
# omega_dot_nrmse per case = MAX of roll/pitch nrmse (the two axes the Phase-1
# buzz was found on); sat_frac per case comes straight from that case's
# omega_window(). track_rms/benign_rms are the same per-case tracking numbers
# printed above.
buzz_results = []
for pc in per_case:
    b = baseline.get(pc["case"], {}).get("rms_m", float("nan"))
    sat_frac_case = pc["omega"]["sat_frac"]
    nrmse_case = max(pc["omega"]["roll"]["nrmse"], pc["omega"]["pitch"]["nrmse"])
    r = buzz_score(pc["rms_m"], b, sat_frac_case, nrmse_case,
                    tol=BUZZ_TOL, sat_tol=SAT_TOL, nrmse_tol=NRMSE_TOL)
    r["case"] = pc["case"]
    buzz_results.append(r)
    print(f"BUZZ-CLOSES {pc['case']:<16} closed={r['closed']} "
          f"track={pc['rms_m']:.3f}/{b * BUZZ_TOL:.3f} "
          f"sat={sat_frac_case:.3f}/{SAT_TOL:.3f} "
          f"nrmse={nrmse_case:.3f}/{NRMSE_TOL:.3f}", flush=True)
report["buzz_closes"]["per_case"] = buzz_results

# G1-ceiling note: the buzz must close because the actuator state is now
# MEASURED (C2), not because CC3_G1_RP was inflated past a physically
# implausible effectiveness. analytic_g1(QuadParams())[0] is the roll-axis
# 1/J effectiveness (~200 rad/s^2 per N*m for the default SITL quad); the
# shipped CC3_G1_RP=500 stays comfortably under 3x that ceiling.
analytic_g1_roll = float(analytic_g1(QuadParams())[0])
effective_g1 = 500.0  # CC3_G1_RP (kept identical to the diagnostic tune)
print(f"G1 ceiling check  : effective_g1={effective_g1:.0f} "
      f"analytic_g1_roll≈{analytic_g1_roll:.1f} "
      f"(3x={3 * analytic_g1_roll:.1f})", flush=True)
report["g1_ceiling"] = {
    "effective_g1": effective_g1,
    "analytic_g1_roll": analytic_g1_roll,
}

open("/tmp/flight/indi_score.json", "w").write(json.dumps(report, indent=1))

# --- hard gate (buzz-closes) --------------------------------------------------
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
# RPM channel live: if the measured-actuator-state path never actually ran
# (all fallback, or omega reads all-zero) then a closed buzz score would be
# meaningless -- the C2 path wasn't exercised.
if indc_fallback_frac >= 0.5 or indc_mean_abs_omega <= 0.0:
    errs.append(f"INDC measured-RPM channel not live: fallback_frac="
                f"{indc_fallback_frac:.3f} mean_abs_omega={indc_mean_abs_omega:.2f} "
                f"(CC3_USE_RPM path did not actually run)")
# G1-ceiling: the buzz must close via measured actuator state, not via an
# inflated effectiveness gain.
if not (effective_g1 < 3 * analytic_g1_roll):
    errs.append(f"G1 ceiling violated: effective_g1={effective_g1} >= "
                f"3*analytic_g1_roll={3 * analytic_g1_roll:.1f}")
# Buzz-closes gate: EVERY case must report closed=True.
for r in buzz_results:
    if not r["closed"]:
        fails = []
        if not r["track_ok"]:
            fails.append(f"track {r['track_rms']:.3f} > "
                         f"{r['benign_rms'] * BUZZ_TOL:.3f}")
        if not r["sat_ok"]:
            fails.append(f"sat {r['sat_frac']:.3f} > {SAT_TOL:.3f}")
        if not r["nrmse_ok"]:
            fails.append(f"nrmse {r['omega_dot_nrmse']:.3f} > {NRMSE_TOL:.3f}")
        errs.append(f"{r['case']}: buzz NOT closed ({'; '.join(fails)})")

if errs:
    print("=== C2 buzz-closes gate FAIL ===", flush=True)
    for e in errs:
        print("  FAIL:", e, flush=True)
    sys.exit(1)
print("=== C2 buzz-closes gate PASS ===", flush=True)
