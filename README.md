# anixpkgs

![example workflow](https://github.com/goromal/anixpkgs/actions/workflows/test.yml/badge.svg) [![Deploy](https://github.com/goromal/anixpkgs/actions/workflows/deploy.yml/badge.svg?event=push)](https://github.com/goromal/anixpkgs/actions/workflows/deploy.yml) [![pages-build-deployment](https://github.com/goromal/anixpkgs/actions/workflows/pages/pages-build-deployment/badge.svg)](https://github.com/goromal/anixpkgs/actions/workflows/pages/pages-build-deployment)

![](https://raw.githubusercontent.com/goromal/anixdata/master/data/img/anixpkgs.png "anixpkgs")

**LATEST RELEASE: [v8.27.3](https://github.com/goromal/anixpkgs/tree/v8.27.3)**

**[Docs Website](https://goromal.github.io/anixpkgs/)**

A collection of personal (or otherwise personally useful) repositories and NixOS closures packaged as a [nixpkgs](https://github.com/NixOS/nixpkgs) overlay.

## Update Dependencies

To systematically update all (self-owned) dependencies, run

```bash
python scripts/update_deps.py
```

## Lint

To lint all `.nix` files, run

```bash
nix-shell -p nixfmt --run "bash scripts/lint.sh"
```

## Docs

Comprehensive documentation for individual packages and common NixOS use cases is served in site form [here](https://goromal.github.io/anixpkgs/) using `mdbook` on the `docs/` directory. To generate new docs, run

```bash
NIXPKGS_ALLOW_UNFREE=1 python scripts/generate_docs.py
```

*Auto-generated as part of CD pipeline.*

## Tests

To build all packages and run their respective unit tests, run

```bash
bash scripts/build_pkgs.sh cpp
bash scripts/build_pkgs.sh rust
bash scripts/build_pkgs.sh python
bash scripts/build_pkgs.sh bash
bash scripts/build_pkgs.sh java
```

To run regression tests, run

```bash
cd test
nix-shell --run "bash test.sh"
```

*Automatically run as part of CI pipeline.*

## Closure Verifications

To check the validity of all NixOS closures (without actually building them), run

```bash
bash scripts/check_machines.sh
```

*Automatically run as part of CI pipeline.*

## NixOS Profile Diff

To compare NixOS profile closures between a PR branch and its merge base, trigger the **NixOS Profile Diff** workflow manually from the GitHub Actions UI:

1. Go to **Actions → NixOS Profile Diff → Run workflow**
2. Select the PR branch from the branch dropdown
3. Optionally enter the PR number in the `pr_number` field to have the diff posted as a comment (replacing any previous one); leave blank to only log the output

The job evaluates each known machine configuration (`personal-*`, `ats-*`, `jetpack-*`) on both the PR branch and the merge-base, reports any package additions or removals per profile, and flags new or deleted profiles.

## SITL

Some commands to spin up SITL environments:

```bash
# Drone Sim
bash scripts/sitl/drone-sim.sh
```
