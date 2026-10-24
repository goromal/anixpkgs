#!/bin/bash

set -e

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
SOURCE="$(readlink "$SOURCE")"
[[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
cd "$DIR/.."

if [[ "$1" == "check" ]]; then
    echo "Validating format of .nix files..."
    find . -type f -name "*.nix" -print0 | xargs -0 nixfmt -c
else
    echo "Formatting .nix files..."
    find . -type f -name "*.nix" -print0 | xargs -0 nixfmt
fi
echo "Done."
