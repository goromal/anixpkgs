# anixpkgs

A collection of personal (or otherwise personally useful) repositories packaged as Nix overlays.

## Usage

To use, clone this repo and add to `~/.bashrc`:

```bash
export NIX_PATH=anixpkgs=/your/path/to/anixpkgs
```

and in your Nix derivations:

```nix
pkgs = import <anixpkgs>; # a set, not a function
```
An example Nix shell for trying out Python packages:

```nix
{ pkgs ? import <anixpkgs> }:
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
