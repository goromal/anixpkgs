import json
import os
from subprocess import check_output, CalledProcessError, DEVNULL

ANIXDIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

with open(os.path.join(ANIXDIR, "flake.lock"), "r") as lockfile:
    lock = json.loads(lockfile.read())

print("Checking for auto-updateable sources...")
for src in lock["nodes"]:
    if "original" in lock["nodes"][src]:
        original = lock["nodes"][src]["original"]
        if ("owner" in original and original["owner"] == "goromal") or ("url" in original and "gist" in original["url"]):
            print(f"  {src}")
            try:
                output = check_output(["nix", "flake", "update", src], stderr=DEVNULL)
            except CalledProcessError:
                print(f"  ERROR updating flake input {src}")
                exit(1)
print("...done.")
