#!/bin/bash

set -e pipefail

nb() {
nix-build . -A $1
}

echo "Building C++ packages..."

nb manif-geom-cpp
nb ceres-factors
nb signals-cpp
nb secure-delete
nb sorting
nb crowcpp
