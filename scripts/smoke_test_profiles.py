#!/usr/bin/env python3
"""Smoke-test NixOS profile option permutations via pairwise (all-pairs) coverage.

Tests that every pair of boolean option values can co-exist without a Nix
evaluation error, catching module-level conflicts without exhaustive 2^N checks.
"""

import os
import random
import subprocess
import sys
import tempfile
import time
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent.resolve()
NIXOS_DIR = REPO_ROOT / "pkgs/nixos"
NIXOS_STATE = os.environ.get("NIXOS_VERSION", "25.11")

BOOL_OPTIONS = [
    "graphical",
    "recreational",
    "developer",
    "isATS",
    "serveNotesWiki",
    "enableMetrics",
    "enableFileServers",
    "enableOrchestrator",
]

# x86 only in CI; pi4/jetson require cross-compilation setup
MACHINE_TYPES = ["x86_linux"]

DEPS_NIX = NIXOS_DIR / "dependencies.nix"


def pairwise_cases(options, seed=42):
    """Greedy all-pairs generator: covers every (opt_i=v, opt_j=v) pair."""
    random.seed(seed)
    needed = {
        (o1, v1, o2, v2)
        for i, o1 in enumerate(options)
        for o2 in options[i + 1 :]
        for v1 in (True, False)
        for v2 in (True, False)
    }
    cases = []
    while needed:
        best, best_cover = None, set()
        for _ in range(200):
            candidate = {o: random.choice([True, False]) for o in options}
            cover = {
                (o1, candidate[o1], o2, candidate[o2])
                for i, o1 in enumerate(options)
                for o2 in options[i + 1 :]
            } & needed
            if len(cover) > len(best_cover):
                best, best_cover = candidate, cover
        cases.append(best)
        needed -= best_cover
    return cases


def render_config(machine_type, opts):
    bool_lines = "\n".join(
        f"  machines.base.{k} = {'true' if v else 'false'};"
        for k, v in opts.items()
    )
    return f"""\
{{ ... }}:
{{
  imports = [ {NIXOS_DIR}/pc-base.nix ];
  machines.base.nixosState = "{NIXOS_STATE}";
  machines.base.machineType = "{machine_type}";
  machines.base.cloudDirs = [];
{bool_lines}
  networking.hostName = "smoke-test";
  # Minimal stub so fileSystems assertion passes
  fileSystems."/" = {{ device = "none"; fsType = "tmpfs"; }};
  boot.loader.grub.enable = false;
}}
"""


def eval_config(config_str, label):
    with tempfile.NamedTemporaryFile(suffix=".nix", mode="w", delete=False) as f:
        f.write(config_str)
        tmp = f.name
    try:
        t0 = time.monotonic()
        # Eval config.assertions: forces module merge and all assertion checks
        # without building any derivation. ~3-4s per check vs ~86s for --dry-run.
        r = subprocess.run(
            [
                "nix",
                "eval",
                "--impure",
                "--expr",
                f"(import <nixpkgs/nixos> {{ configuration = {tmp}; }}).config.assertions",
            ],
            env={
                **os.environ,
                "NIXPKGS_ALLOW_UNFREE": "1",
                "NIXPKGS_ALLOW_INSECURE": "1",
                "NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM": "1",
            },
            capture_output=True,
            text=True,
        )
        elapsed = time.monotonic() - t0
        ok = r.returncode == 0
        status = "OK  " if ok else "FAIL"
        print(f"  [{status}] {label} ({elapsed:.1f}s)")
        if not ok:
            print(r.stderr[-2000:])
        return ok, elapsed
    finally:
        os.unlink(tmp)


class _LocalBuildPatch:
    def __enter__(self):
        text = DEPS_NIX.read_text()
        if "local-build = false;" in text:
            DEPS_NIX.write_text(text.replace("local-build = false;", "local-build = true;"))
        return self

    def __exit__(self, *_):
        text = DEPS_NIX.read_text()
        if "local-build = true;" in text:
            DEPS_NIX.write_text(text.replace("local-build = true;", "local-build = false;"))


def main():
    cases = pairwise_cases(BOOL_OPTIONS)
    total = len(cases) * len(MACHINE_TYPES)
    print(f"Pairwise cases: {len(cases)}  machine types: {MACHINE_TYPES}  total checks: {total}")
    print()

    failures = []
    timings = []

    with _LocalBuildPatch():
        for mt in MACHINE_TYPES:
            for i, opts in enumerate(cases):
                short = " ".join(
                    f"{k[:3]}={'T' if v else 'F'}" for k, v in opts.items()
                )
                label = f"{mt}/perm-{i:03d}  {short}"
                ok, elapsed = eval_config(render_config(mt, opts), label)
                timings.append(elapsed)
                if not ok:
                    failures.append(label)

    print()
    print(f"Timings: min={min(timings):.1f}s  max={max(timings):.1f}s  "
          f"avg={sum(timings)/len(timings):.1f}s  total={sum(timings):.1f}s")

    if failures:
        print(f"\n{len(failures)}/{total} FAILED:")
        for f in failures:
            print(f"  {f}")
        sys.exit(1)

    print(f"\nAll {total} permutations passed.")


if __name__ == "__main__":
    main()
