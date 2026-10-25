import json
import os
from subprocess import check_output, CalledProcessError, DEVNULL

ANIXDIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

with open(os.path.join(ANIXDIR, "flake.lock"), "r") as lockfile:
    lock = json.loads(lockfile.read())

print("Checking for auto-updateable sources...")
srcs = []
for src in lock["nodes"]:
    if "original" in lock["nodes"][src]:
        original = lock["nodes"][src]["original"]
        if ("owner" in original and original["owner"] == "goromal") or ("url" in original and "gist" in original["url"]):
            print(f"  {src}")
            srcs.append(src)
# One invocation updates every input in a single lock pass.
if srcs:
    try:
        output = check_output(["nix", "flake", "update", *srcs], stderr=DEVNULL)
    except CalledProcessError:
        print(f"  ERROR updating flake inputs {' '.join(srcs)}")
        exit(1)
print("...done.")
