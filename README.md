# anixpkgs

![example workflow](https://github.com/goromal/anixpkgs/actions/workflows/test.yml/badge.svg)

![](https://raw.githubusercontent.com/goromal/anixdata/master/data/img/anixpkgs.png "anixpkgs")

A collection of personal (or otherwise personally useful) repositories and NixOS closures packaged as Nix overlays.

## Docs

Comprehensive documentation for individual packages and common NixOS use cases is served locally [here](./docs/src/SUMMARY.md) and in site form [here](https://goromal.github.io/anixpkgs/) using `mdbook` on the `docs/` directory. To generate new docs, run

```bash
python scripts/generate_docs.py
```

## Tests

To build all packages and run their respective tests, run

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

## Update Dependencies

To systematically update all (self-owned) dependencies, run

```bash
python scripts/update_deps.py
```
