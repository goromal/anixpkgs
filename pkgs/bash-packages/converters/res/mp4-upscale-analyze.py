"""Measure the color fixes mp4-upscale applies to an old video.

    mp4-upscale-analyze INFILE CROP START END SENDCMD_OUT

CROP is W:H:X:Y; START/END are ffmpeg times or empty strings. Prints
"chroma H V": the chroma-to-luma offset in luma pixels, 0 0 when not clearly
measurable. Writes ffmpeg sendcmd lines driving colorchannelmixer@wb with a
temporally smoothed grey-edge white balance to SENDCMD_OUT (times relative to
the trimmed output).
"""

import subprocess
import sys

import numpy as np

infile, crop, start, end, cmd_out = sys.argv[1:6]
cw, ch, cx, cy = (int(v) for v in crop.split(":"))

trim = []
if start:
    trim += ["-ss", start]
if end:
    trim += ["-to", end]


def duration():
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "csv=p=0", infile],
        capture_output=True, text=True).stdout.strip()
    return float(out or 0)


def to_seconds(t):
    secs = 0.0
    for part in t.split(":"):
        secs = secs * 60 + float(part)
    return secs


# ---------------------------------------------------------------- chroma offset
# VHS decks commonly delay chroma relative to luma. Correlate the edge maps of
# the chroma planes with the luma edge map over candidate shifts; the shift
# with the best correlation is the offset. Chroma is heavily blurred, so the
# profile is broad: only a clear win over "no shift" is reported.
SHIFTS = range(-6, 7)


def edge_scores(y, c, axis):
    gy = np.abs(np.gradient(y, axis=axis))[10:-10, 10:-10].ravel()
    gc = np.abs(np.gradient(c, axis=axis))
    return np.array([
        np.corrcoef(gy, np.roll(gc, -s, axis=axis)[10:-10, 10:-10].ravel())[0, 1]
        for s in SHIFTS])


t0 = to_seconds(start) if start else 0.0
t1 = to_seconds(end) if end else duration()
span = max(t1 - t0, 0.1)
h_tot = np.zeros(len(SHIFTS))
v_tot = np.zeros(len(SHIFTS))
n = 0
for frac in np.linspace(0.05, 0.95, 24):
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-nostdin", "-ss", f"{t0 + span * frac:.3f}",
         "-i", infile, "-frames:v", "1", "-vf", f"crop={crop}",
         "-pix_fmt", "yuv444p", "-f", "rawvideo", "-"],
        capture_output=True).stdout
    if len(raw) < 3 * cw * ch:
        continue
    y, u, v = np.frombuffer(raw[:3 * cw * ch], np.uint8).reshape(3, ch, cw).astype(float)
    if y.std() < 8:  # blank or near-black frame: no edges to measure
        continue
    for c in (u, v):
        h_tot += np.nan_to_num(edge_scores(y, c, 1))
        v_tot += np.nan_to_num(edge_scores(y, c, 0))
    n += 2


def pick(tot):
    if n == 0:
        return 0
    prof = tot / n
    best = int(np.argmax(prof))
    zero = SHIFTS.index(0)
    return SHIFTS[best] if prof[best] - prof[zero] > 0.01 else 0


print(f"chroma {pick(h_tot)} {pick(v_tot)}")

# --------------------------------------------------------------- white balance
# ffmpeg's greyedge (difford=1, Minkowski p=5, sigma=2) estimates the
# illuminant from edges, so a frame dominated by sky or water is not forced to
# grey the way gray-world forces it. It has no temporal smoothing, though, so
# it is run only on frames sampled at 2 fps, its effective per-channel gain is
# read back as the ratio of channel means after/before, and the gains are
# clamped, smoothed over a few seconds and applied by colorchannelmixer.
RATE = 2
SW, SH = 88, 58
proc = subprocess.Popen(
    ["ffmpeg", "-v", "error", "-nostdin", *trim, "-i", infile, "-an",
     "-filter_complex",
     f"[0:v]crop={crop},fps={RATE},format=gbrp,split[a][b];"
     "[b]greyedge=difford=1:minknorm=5:sigma=2[g];"
     f"[a]scale={SW}:{SH}:flags=area[a2];[g]scale={SW}:{SH}:flags=area[g2];"
     "[a2][g2]hstack,format=rgb24",
     "-f", "rawvideo", "-"],
    stdout=subprocess.PIPE)
frame_bytes = 2 * SW * SH * 3
gains = []
while True:
    raw = proc.stdout.read(frame_bytes)
    if len(raw) < frame_bytes:
        break
    img = np.frombuffer(raw, np.uint8).reshape(SH, 2 * SW, 3).astype(float)
    before = img[:, :SW].reshape(-1, 3).mean(axis=0)
    after = img[:, SW:].reshape(-1, 3).mean(axis=0)
    if before.min() < 8:  # near-black frame: nothing to measure
        gains.append(None)
        continue
    gains.append(after / before)
proc.wait()

good = [g for g in gains if g is not None]
neutral = np.ones(3)
g = np.array([gg if gg is not None else (good[0] if good else neutral)
              for gg in gains]) if gains else np.ones((1, 3))
g = 1 + 0.85 * (np.clip(g, 0.8, 1.25) - 1)


def smooth(a, k, fn):
    pad = np.pad(a, ((k // 2, k // 2), (0, 0)), mode="edge")
    return np.array([fn(pad[i:i + k], axis=0) for i in range(len(a))])


g = smooth(smooth(g, 7, np.median), 5, np.mean)
# Keep brightness: normalize so the gains leave luma unchanged.
g /= (g * np.array([0.299, 0.587, 0.114])).sum(axis=1, keepdims=True)

with open(cmd_out, "w") as fh:
    for i, (r, gg, b) in enumerate(g):
        t = i / RATE
        fh.write(f"{t:.3f} colorchannelmixer@wb rr {r:.4f}, "
                 f"colorchannelmixer@wb gg {gg:.4f}, "
                 f"colorchannelmixer@wb bb {b:.4f};\n")
