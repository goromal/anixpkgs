# anixpkgs

![example workflow](https://github.com/goromal/anixpkgs/actions/workflows/test.yml/badge.svg) [![Deploy](https://github.com/goromal/anixpkgs/actions/workflows/deploy.yml/badge.svg?event=push)](https://github.com/goromal/anixpkgs/actions/workflows/deploy.yml) [![pages-build-deployment](https://github.com/goromal/anixpkgs/actions/workflows/pages/pages-build-deployment/badge.svg)](https://github.com/goromal/anixpkgs/actions/workflows/pages/pages-build-deployment)

![](https://raw.githubusercontent.com/goromal/anixdata/master/data/img/anixpkgs.png "anixpkgs")

**LATEST RELEASE: [v8.44.1](https://github.com/goromal/anixpkgs/tree/v8.44.1)**

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

The job evaluates each known machine configuration (`personal-*`, `ats-*`, `jetpack-*`, `drone-*`) on both the PR branch and the merge-base, reports any package additions or removals per profile, and flags new or deleted profiles.

## Manual Release Tag

If a PR gets merged without a `MajorRelease`/`MinorRelease`/`PatchRelease` label (so `deploy.yml` doesn't bump `ANIX_VERSION` or cut a tag), trigger the **Manual Release Tag** workflow to do it after the fact:

1. Go to **Actions → Manual Release Tag → Run workflow**
2. Choose a `release_type` of `major`, `minor`, or `patch`
3. Run it (branch selection in the dropdown doesn't matter — the job always operates on the head of `master`)

The job bumps `ANIX_VERSION` accordingly, commits and pushes to `master`, then tags the new version as `v<ANIX_VERSION>` and pushes the tag.

## SITL

Some commands to spin up SITL environments:

```bash
# Drone Sim
bash scripts/sitl/drone-sim.sh
```

The script builds the `driverInteractive` attribute of `pkgs/nixos/sitl-envs/dronesim.nix` and drops into the [interactive NixOS test driver](https://nixos.org/manual/nixos/stable/#sec-running-nixos-tests-interactively) (a Python REPL). From there:

```python
machines[0].start()           # boot the drone-obc-sitl VM
machines[0].shell_interact()  # open a root shell in the VM
```

The VM's SSH port is forwarded to the host, so it can also be reached with

```bash
ssh drone@localhost -p 4444
```

The drone closure ships the core ROS2 (jazzy) infrastructure from [nix-ros-overlay](https://github.com/lopsided98/nix-ros-overlay), including the `ros2` CLI tools. To sanity-check pub/sub inside the VM:

```bash
ros2 run demo_nodes_cpp talker &
ros2 topic echo /chatter
```

To run the non-interactive smoke test (boots the VM and verifies the ROS2 CLI and a pub/sub round-trip):

```bash
nix-build pkgs/nixos/sitl-envs/dronesim.nix -A driver && ./result/bin/nixos-test-driver
```
