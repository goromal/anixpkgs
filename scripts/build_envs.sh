#!/bin/bash

set -eo pipefail

nb() {
nix-build . -A $1
}

echo "Building build environments..."

nb clangStdenv
nb python39
nb python39.pkgs.pybind11
nb python310
nb rustPlatform
