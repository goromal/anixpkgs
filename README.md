# anixpkgs

![example workflow](https://github.com/goromal/anixpkgs/actions/workflows/test.yml/badge.svg) [![Deploy](https://github.com/goromal/anixpkgs/actions/workflows/deploy.yml/badge.svg?event=push)](https://github.com/goromal/anixpkgs/actions/workflows/deploy.yml) [![pages-build-deployment](https://github.com/goromal/anixpkgs/actions/workflows/pages/pages-build-deployment/badge.svg)](https://github.com/goromal/anixpkgs/actions/workflows/pages/pages-build-deployment)

![](https://raw.githubusercontent.com/goromal/anixdata/master/data/img/anixpkgs.png "anixpkgs")

**[Docs Website](https://goromal.github.io/anixpkgs/)**

A collection of personal (or otherwise personally useful) repositories and NixOS closures packaged as Nix overlays.

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
python scripts/generate_docs.py
```

*Auto-generated as part of CD pipeline.*

## Tests

To build all packages and run their respective unit tests, run

```bash
bash scripts/build_misc.sh
bash scripts/build_cpp.sh
bash scripts/build_python.sh
```

To run regression tests, run

```bash
cd test
nix-shell --run "bash test.sh"
```

*Automatically run as part of CI pipeline.*
