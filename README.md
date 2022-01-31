# anixpkgs

A collection of personal (or otherwise personally useful) repositories packaged as Nix overlays.

The philosophy for the library implementations (and, sometimes, re-implementations) is to facilitate:

- Implementation and notation consistency
- Seamless interoperability
- Quick idea and calculation prototyping

To use, clone this repo and add to `~/.bashrc`:

```bash
export NIX_PATH=nixpkgs=/your/path/to/anixpkgs
```

and in your Nix derivations:

```nix
let pkgs = import <nixpkgs> {};
```
An example Nix shell for trying out Python packages:

```nix
{ pkgs ? import <nixpkgs> {} }:
let
  python-with-my-packages = pkgs.python38.withPackages (p: with p; [
    numpy
    matplotlib
    geometry
    pyceres
  ]);
in
python-with-my-packages.env
```
