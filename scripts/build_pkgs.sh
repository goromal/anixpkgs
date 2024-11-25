#!/bin/bash

set -eo pipefail

pkgstype=$1

nb() {
nix-build . -A $1
}

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
SOURCE="$(readlink "$SOURCE")"
[[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
cd "$DIR/.."

export NIXPKGS_ALLOW_UNFREE=1

echo "Building $pkgstype packages..."

for pkg in $(python3 scripts/filter_pkg_list.py $pkgstype); do
    nb $pkg
done
