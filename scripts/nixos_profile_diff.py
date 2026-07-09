#!/usr/bin/env python3
"""Compare NixOS profile closures between two repo checkouts.

Usage: nixos_profile_diff.py <base_dir> <pr_dir> [output_file]
  base_dir    Path to base branch checkout
  pr_dir      Path to PR branch checkout
  output_file Path to write markdown report (default: stdout)
"""

import os
import re
import subprocess
import sys
from pathlib import Path

KNOWN_CONFIGURATIONS = [
    "jetpack-orin-nx",
    "personal-inspiron",
    "personal-panasonic",
    "personal-dell",
    "ats-alderlake",
    "ats-pi",
    "drone-obc-sitl",
]

NIX_ENV = {
    **os.environ,
    "NIXPKGS_ALLOW_UNFREE": "1",
    "NIXPKGS_ALLOW_INSECURE": "1",
    "NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM": "1",
}


def patch_local_build(repo_dir: str, enable: bool) -> None:
    deps = Path(repo_dir) / "pkgs/nixos/dependencies.nix"
    text = deps.read_text()
    if enable:
        text = text.replace("local-build = false;", "local-build = true;")
    else:
        text = text.replace("local-build = true;", "local-build = false;")
    deps.write_text(text)


def instantiate(repo_dir: str, config: str) -> str | None:
    """Return .drv path, 'ERROR', or None if config file absent."""
    config_path = Path(repo_dir) / f"pkgs/nixos/configurations/{config}.nix"
    if not config_path.exists():
        return None
    result = subprocess.run(
        [
            "nix-instantiate",
            "<nixpkgs/nixos>",
            "-A", "config.system.build.toplevel",
            "-I", f"nixos-config={config_path}",
            "--no-gc-warning",
        ],
        capture_output=True,
        text=True,
        env=NIX_ENV,
    )
    if result.returncode != 0:
        print(f"    {config}: eval failed:\n{result.stderr[-3000:]}", flush=True)
        return "ERROR"
    return result.stdout.strip().splitlines()[-1]  # last line is the .drv path


def closure_names(drv_path: str) -> set[str]:
    """Return set of package name-version strings from the derivation closure."""
    result = subprocess.run(
        ["nix-store", "--query", "--requisites", drv_path],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return set()
    names = set()
    for line in result.stdout.strip().splitlines():
        # /nix/store/<hash>-<name> -> <name>
        m = re.match(r"/nix/store/[a-z0-9]{32}-(.+)", line)
        if m:
            names.add(m.group(1))
    return names


def fmt_pkg_list(items: set[str], marker: str) -> str:
    return "\n".join(f"  {marker} `{item}`" for item in sorted(items))


def main() -> None:
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        sys.exit(1)

    base_dir = sys.argv[1]
    pr_dir = sys.argv[2]
    output_file = sys.argv[3] if len(sys.argv) > 3 else None

    for d in (base_dir, pr_dir):
        patch_local_build(d, True)

    try:
        base_configs = {p.stem for p in (Path(base_dir) / "pkgs/nixos/configurations").glob("*.nix")}
        pr_configs   = {p.stem for p in (Path(pr_dir)   / "pkgs/nixos/configurations").glob("*.nix")}
        all_configs  = sorted((base_configs | pr_configs) & set(KNOWN_CONFIGURATIONS))

        # (config, status, added_set | None, removed_set | None)
        results = []

        for config in all_configs:
            in_base = config in base_configs
            in_pr   = config in pr_configs

            if not in_base:
                results.append((config, "new", None, None))
                continue
            if not in_pr:
                results.append((config, "deleted", None, None))
                continue

            print(f"  Evaluating {config}...", flush=True)
            base_drv = instantiate(base_dir, config)
            pr_drv   = instantiate(pr_dir,   config)

            if base_drv == "ERROR" and pr_drv == "ERROR":
                results.append((config, "both_error", None, None))
            elif base_drv == "ERROR":
                results.append((config, "new", None, None))
            elif pr_drv == "ERROR":
                results.append((config, "deleted", None, None))
            elif base_drv == pr_drv:
                results.append((config, "unchanged", None, None))
            else:
                print(f"    {config}: derivation changed, computing closure diff...", flush=True)
                base_names = closure_names(base_drv)
                pr_names   = closure_names(pr_drv)
                added   = pr_names   - base_names
                removed = base_names - pr_names
                results.append((config, "changed", added, removed))

        # ── Build report ──────────────────────────────────────────────────────
        lines = ["## NixOS Profile Diff", ""]

        # Summary table
        lines += ["| Profile | Status |", "|---------|--------|"]
        for config, status, added, removed in results:
            if status == "unchanged":
                badge = "✅ No delta"
            elif status == "new":
                badge = "🆕 New profile"
            elif status == "deleted":
                badge = "🗑️ Deleted"
            elif status == "both_error":
                badge = "❌ Eval error on both branches"
            elif not added and not removed:
                badge = "✅ No delta (hash only)"
            else:
                badge = f"⚠️ +{len(added)} / -{len(removed)} packages"
            lines.append(f"| `{config}` | {badge} |")

        # Detail blocks for changed profiles
        for config, status, added, removed in results:
            if status != "changed":
                continue
            summary = f"`{config}` — +{len(added)} / -{len(removed)} packages"
            lines += [f"\n<details><summary>{summary}</summary>", ""]
            if added:
                lines.append("**Added:**")
                lines.append(fmt_pkg_list(added, "+"))
            if removed:
                lines.append("\n**Removed:**")
                lines.append(fmt_pkg_list(removed, "-"))
            lines.append("\n</details>")

        report = "\n".join(lines) + "\n"

        if output_file:
            Path(output_file).write_text(report)
        else:
            print(report)

    finally:
        for d in (base_dir, pr_dir):
            patch_local_build(d, False)


if __name__ == "__main__":
    main()
