import json
import os

ANIXDIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

branches_whitelist = ["nixpkgs-unstable", "Copter-4.4", "master", "main"]

def is_whitelisted(ref):
    """Check if a ref is whitelisted, including version-agnostic patterns."""
    if ref in branches_whitelist:
        return True
    # Allow nixos-XX.YY version branches
    if ref.startswith("nixos-"):
        return True
    return False

with open(os.path.join(ANIXDIR, "flake.lock"), "r") as lockfile:
    lock = json.loads(lockfile.read())

for src in lock["nodes"]:
    if "original" in lock["nodes"][src]:
        original = lock["nodes"][src]["original"]
        if (
            "ref" in original
            and "refs/" not in original["ref"]
            and not is_whitelisted(original["ref"])
        ):
            print(f"Source {src} is checked out on a side branch: {original['ref']}")
