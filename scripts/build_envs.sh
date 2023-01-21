#!/bin/bash

set -e pipefail

nb() {
nix-build . -A $1
}

echo "Building build environments..."

nb clangStdenv
nb python3
nb python3.pybind11
nb python310
nb rustPlatform
