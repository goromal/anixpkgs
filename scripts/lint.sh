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
    for nixfile in $(find . -type f -name "*.nix"); do
        nixfmt -c "$nixfile"
    done
else
    echo "Formatting .nix files..."
    for nixfile in $(find . -type f -name "*.nix"); do 
        nixfmt "$nixfile"
    done
fi
echo "Done."
