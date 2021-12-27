# anixpkgs

A collection of personal (or otherwise personally useful) repositories packaged as Nix overlays.

To use, clone this repo and add to `~/.bashrc`:

```bash
export NIX_PATH=anixpkgs=/your/path/to/anixpkgs
```

and in your Nix derivations:

```nix
pkgs = import <anixpkgs>; # a set, not a function
```
