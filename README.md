# anixpkgs

![example workflow](https://github.com/goromal/anixpkgs/actions/workflows/test.yml/badge.svg) [![Deploy](https://github.com/goromal/anixpkgs/actions/workflows/deploy.yml/badge.svg?event=push)](https://github.com/goromal/anixpkgs/actions/workflows/deploy.yml) [![pages-build-deployment](https://github.com/goromal/anixpkgs/actions/workflows/pages/pages-build-deployment/badge.svg)](https://github.com/goromal/anixpkgs/actions/workflows/pages/pages-build-deployment)

![](https://raw.githubusercontent.com/goromal/anixdata/master/data/img/anixpkgs.png "anixpkgs")

**LATEST RELEASE: [v6.23.16](https://github.com/goromal/anixpkgs/tree/v6.23.16)**

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

## SITL

Some commands to spin up SITL environments:

```bash
# Drone Sim
bash scripts/sitl/drone-sim.sh
```
