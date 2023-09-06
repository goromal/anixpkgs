#!/bin/bash

set -eo pipefail

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

echo "Building miscellaneous packages..."

for pkg in $(python3 scripts/filter_pkg_list.py misc); do
    nb $pkg
done
