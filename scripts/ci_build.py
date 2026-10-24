#!/usr/bin/env python3
"""Evaluate CI targets (scripts/ci_targets.nix) in parallel and build what is missing.

Targets are evaluated in parallel with nix-eval-jobs. A target whose default
output (what `nix-build -A <attr>` realises) is already valid locally or in a
configured binary cache was built from the identical derivation, so it already
passes the build check; only the remaining targets are realised. This skips
downloading the closures of the (usually many) unchanged packages.

Usage:
    python3 scripts/ci_build.py [--envs] [--fetch-cached] CATEGORY...
"""

import argparse
import json
import os
import shutil
import subprocess
import sys

ANIXDIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGETS_NIX = os.path.join(ANIXDIR, "scripts", "ci_targets.nix")
CATEGORIES = ["cpp", "rust", "python", "bash", "java", "js"]
# nix-eval-jobs restarts a worker that exceeds this after its current job.
WORKER_MEMORY_MIB = 3072
NIX_ENV = dict(os.environ, NIXPKGS_ALLOW_UNFREE="1")


def _nix_eval_jobs(args):
    """Command line for nix-eval-jobs, from PATH or else this repo's pinned nixpkgs.

    The pinned build does not depend on <nixpkgs>, which deploy.yml once left
    unset.
    """
    if shutil.which("nix-eval-jobs"):
        return ["nix-eval-jobs"] + args
    out = subprocess.run(
        ["nix-build", ANIXDIR, "-A", "nix-eval-jobs", "--no-out-link"],
        stdout=subprocess.PIPE,
        text=True,
        check=True,
    ).stdout.strip()
    return [os.path.join(out, "bin", "nix-eval-jobs")] + args


def _default_output(record):
    """`drv!output` path for the output that `nix-build -A <attr>` realises."""
    return f"{record['drvPath']}!{record['extraValue']['output']}"


def evaluate(categories, envs=False, docs=False, workers=None):
    """Evaluate the selected targets; returns nix-eval-jobs records by attr."""
    nix_list = "[ " + " ".join(f'"{c}"' for c in categories) + " ]"
    args = [
        "--impure",
        "--workers",
        str(workers or os.cpu_count() or 1),
        "--max-memory-size",
        str(WORKER_MEMORY_MIB),
        "--apply",
        "drv: { output = drv.outputName; }",
        "--arg",
        "categories",
        nix_list,
        "--arg",
        "envs",
        "true" if envs else "false",
        "--arg",
        "docs",
        "true" if docs else "false",
        TARGETS_NIX,
    ]
    proc = subprocess.run(
        _nix_eval_jobs(args), stdout=subprocess.PIPE, text=True, env=NIX_ENV, cwd=ANIXDIR
    )
    records = {}
    errors = []
    for line in proc.stdout.splitlines():
        record = json.loads(line)
        if "error" in record:
            errors.append(record)
        else:
            records[record["attr"]] = record
    for record in errors:
        print(f"ERROR: evaluating {record['attr']}:\n{record['error']}", file=sys.stderr)
    if proc.returncode != 0 or errors:
        sys.exit(f"ERROR: evaluation failed ({len(errors)} target errors)")
    return records


def unbuilt(records):
    """Attrs whose default output is neither valid locally nor substitutable."""
    proc = subprocess.run(
        ["nix-store", "--realise", "--dry-run", *sorted({_default_output(r) for r in records.values()})],
        stderr=subprocess.PIPE,
        text=True,
        env=NIX_ENV,
    )
    if proc.returncode != 0:
        sys.stderr.write(proc.stderr)
        sys.exit("ERROR: could not determine which targets need building")
    # Parse the "derivation(s) will be built:" block of indented .drv paths.
    to_build = set()
    in_block = False
    for line in proc.stderr.splitlines():
        if not line.startswith(" "):
            in_block = "will be built" in line
        elif in_block:
            to_build.add(line.strip())
    return sorted(attr for attr, r in records.items() if r["drvPath"] in to_build)


def realise(records, attrs=None):
    """Realise the default output of the given attrs (default: all records)."""
    wanted = sorted({_default_output(records[a]) for a in (records if attrs is None else attrs)})
    if not wanted:
        return
    proc = subprocess.run(
        ["nix-store", "--realise", "--keep-going", *wanted],
        stdout=subprocess.DEVNULL,
        env=NIX_ENV,
    )
    if proc.returncode != 0:
        sys.exit("ERROR: one or more targets failed to build")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("categories", nargs="*", choices=CATEGORIES)
    parser.add_argument("--envs", action="store_true", help="include build environments")
    parser.add_argument(
        "--fetch-cached",
        action="store_true",
        help="also substitute cached targets into the local store",
    )
    parser.add_argument("--workers", type=int, help="parallel evaluators (default: nproc)")
    args = parser.parse_args()
    if not args.categories and not args.envs:
        parser.error("give at least one category or --envs")

    records = evaluate(args.categories, envs=args.envs, workers=args.workers)
    to_build = unbuilt(records)
    print(f"Evaluated {len(records)} targets:")
    print(f"  already built or cached: {len(records) - len(to_build)}")
    print(f"  to build: {len(to_build)}")
    for attr in to_build:
        print(f"    {attr}")
    sys.stdout.flush()
    realise(records, None if args.fetch_cached else to_build)
    print("All targets built.")


if __name__ == "__main__":
    main()
