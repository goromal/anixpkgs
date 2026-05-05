#!/bin/bash

set -eo pipefail

nb() {
nix-build . -A $1
}

export NIXPKGS_ALLOW_UNFREE=1

echo "Building build environments..."

nb clangStdenv
nb python311
nb python311.pkgs.pybind11
nb python311
nb php74
