import json
import os

ANIXDIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

branches_whitelist = ["nixpkgs-unstable"]

with open(os.path.join(ANIXDIR, "flake.lock"), "r") as lockfile:
    lock = json.loads(lockfile.read())

for src in lock["nodes"]:
    if "original" in lock["nodes"][src]:
        original = lock["nodes"][src]["original"]
        if (
            "ref" in original
            and "refs/" not in original["ref"]
            and original["ref"] not in branches_whitelist
        ):
            print(f"Source {src} is checked out on a side branch: {original['ref']}")
