#!/bin/bash

set -e pipefail

nb() {
nix-build . -A $1
}

echo "Building C++ packages..."

nb aapis-cpp
nb manif-geom-cpp
nb mscpp
nb ceres-factors
nb signals-cpp
nb secure-delete
nb sorting
nb crowcpp
nb rankserver-cpp
nb mfn
