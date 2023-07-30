#!/bin/bash

set -e pipefail

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

echo "Building Python packages..."

for pkg in $(python3 scripts/filter_pkg_list.py python); do
    nb $pkg
done
