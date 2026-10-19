import json
import os
import re

ANIXDIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

branches_whitelist = [
    "nixpkgs-unstable",
    "Copter-4.4",
    "master",
    "main",
    # The ArduPilot INDI backend is maintained on the fork's controller branch.
    # The companion indi-harness is integrated on master (whitelisted above).
    "dev/controller",  # goromal/ardupilot INDI backend
]

# Temporary paired integration branches for the agent-skills extraction and
# msrs bring-up feedback PRs. Remove each exception after anixpkgs is repinned
# to that dependency's main.
dependency_branch_whitelist = {
    ("agent-skills", "msrs-skill-hierarchical-fsm"),
    ("msrs", "msrs-skill-hierarchical-fsm"),
}

def is_whitelisted(ref):
    """Check if a ref is whitelisted, including version-agnostic patterns."""
    if ref in branches_whitelist:
        return True
    # Allow nixos-XX.YY version branches
    if ref.startswith("nixos-"):
        return True
    # Home Manager tracks stable NixOS releases on release-XX.YY branches.
    if re.fullmatch(r"release-\d{2}\.\d{2}", ref):
        return True
    return False


def branch_from_ref(ref):
    """Return a branch name for short or fully qualified branch refs."""
    if ref.startswith("refs/tags/"):
        return None
    return ref.removeprefix("refs/heads/")


def side_branch_dependencies(lock):
    for src, node in lock["nodes"].items():
        ref = node.get("original", {}).get("ref")
        branch = branch_from_ref(ref) if ref is not None else None
        if (
            branch is not None
            and not is_whitelisted(branch)
            and (src, branch) not in dependency_branch_whitelist
        ):
            yield src, branch


def main():
    with open(os.path.join(ANIXDIR, "flake.lock"), "r") as lockfile:
        lock = json.loads(lockfile.read())

    for src, branch in side_branch_dependencies(lock):
        print(f"Source {src} is checked out on a side branch: {branch}")


if __name__ == "__main__":
    main()
