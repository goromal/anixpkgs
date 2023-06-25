# anixpkgs

![example workflow](https://github.com/goromal/anixpkgs/actions/workflows/test.yml/badge.svg)

![](https://raw.githubusercontent.com/goromal/anixdata/master/data/img/anixpkgs.png "anixpkgs")

A collection of personal (or otherwise personally useful) repositories packaged as Nix overlays.

## Docs

Comprehensive documentation for individual packages and common NixOS use cases is served locally [here](./docs/src/SUMMARY.md) and in site form (TODO here) using `mdbook` on the `docs/` directory. To generate new docs, run

```bash
python scripts/generate_docs.py
```

## Tests

To build all packages and run their respective tests, run

```bash
python scripts/build_and_test.py
```
