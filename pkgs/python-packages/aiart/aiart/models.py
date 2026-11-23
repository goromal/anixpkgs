"""Download the weights a mesh workflow declares, resuming partial files."""
import os
import sys

import requests


def pull(model, models_dir, chunk=1 << 22):
    dest_dir = os.path.join(models_dir, model["dir"])
    os.makedirs(dest_dir, exist_ok=True)
    dest = os.path.join(dest_dir, model["name"])
    if os.path.exists(dest):
        return dest
    part = dest + ".part"
    have = os.path.getsize(part) if os.path.exists(part) else 0
    headers = {"Range": "bytes=%d-" % have} if have else {}
    with requests.get(model["url"], headers=headers, stream=True, timeout=60) as r:
        if r.status_code == 200:
            have = 0
        elif r.status_code != 206:
            r.raise_for_status()
        total = model.get("bytes") or (have + int(r.headers.get("content-length", 0)))
        with open(part, "ab" if have else "wb") as f:
            for block in r.iter_content(chunk):
                f.write(block)
                have += len(block)
                if sys.stderr.isatty() and total:
                    sys.stderr.write("\r\033[K%s %.1f/%.1f GB" % (
                        model["name"], have / 1e9, total / 1e9))
    if sys.stderr.isatty():
        sys.stderr.write("\n")
    if model.get("bytes") and os.path.getsize(part) != model["bytes"]:
        raise IOError("%s: size %d, expected %d" % (part, os.path.getsize(part), model["bytes"]))
    os.replace(part, dest)
    return dest
