"""Flatness-outer-loop gate scorer: assert the in-firmware INDI outer loop flew
the full trajectory battery via the DDS flat reference, tracked it, and fell back
cleanly when the reference went stale. This is the one comprehensive drone gate.
Quiet on success (one summary line + PASS); any assert failure surfaces the
summary so a CI failure is self-explaining.

argv: <flight.BIN> <flown.json>
"""
import json
import sys

import numpy as np

from indi_harness.sitl.binlog import read_outer_health
from indi_harness.sitl.align import flat_tracking_score

BIN, FLOWN = sys.argv[1], sys.argv[2]

# Outer-loop tracking (INDB: DDS reference vs measured position, same tick).
h = read_outer_health(BIN)
s = flat_tracking_score(h)                       # active-window ref-vs-measured
fb = np.asarray(h["fallback"], int)
trans = int((np.diff(fb) != 0).sum())            # active<->fallback transitions
act = fb == 0
meas_d = h["meas_p"][act][:, 2] if act.any() else np.array([0.0])
alt_min = float(meas_d.min())                    # most-negative NED-down = peak alt
cases = [f["case"] for f in json.loads(open(FLOWN).read())]

print(f"flatness-outer-loop battery: cases={cases} n={s['n']} "
      f"track_rms_m={s['rms_m']:.3f} track_max_m={s['max_m']:.3f} "
      f"active_frac={s['active_frac']:.3f} fb_transitions={trans} "
      f"peak_alt_m={-alt_min:.1f}", flush=True)

# --- hard gate ---------------------------------------------------------------
# All five battery cases flown via the DDS reference.
assert len(cases) == 5, f"expected 5 battery cases, flew {len(cases)}: {cases}"
# Outer loop genuinely engaged across the battery (not stuck in fallback).
assert s["active_frac"] > 0.4, f"outer loop barely active: {s['active_frac']}"
# Tracks the whole battery. < 1.5 m mathematically forces the figure-eights to
# track: the stock/inner-only controllers sit at ~5.0 m on the slow lemniscate,
# which alone would blow an aggregate this low. Also catches the ~35 m
# collective-runaway and the ~2.2 m parked-at-origin (target-cancellation)
# regressions. Good tracking is itself proof the inner INDI loop delivers real
# roll/pitch torque -- the vehicle could not fly the trajectory otherwise.
assert s["rms_m"] < 1.5, f"battery tracking RMS too high: {s['rms_m']:.3f}"
# No altitude runaway (hover ~9.7 m; the collective-drive bug climbed to ~66 m).
assert alt_min > -14.0, f"altitude runaway suspected: peak {-alt_min:.1f} m"
# The DDS reference goes stale between cases (ready-file unlinked) -> the backend
# must fall back to the stock loop and re-acquire: >=4 transitions over 5 cases.
assert trans >= 4, f"too few fallback transitions ({trans}); DDS-staleness path unexercised"

print("flatness-outer-loop gate PASS", flush=True)
