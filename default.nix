{ pkgs ? import (builtins.fetchGit (import ./pkgs.nix)) { } }:
import ./pkgs/all-packages.nix { inherit pkgs; }
