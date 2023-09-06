#!/bin/bash

set -eo pipefail

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
SOURCE="$(readlink "$SOURCE")"
[[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

echo "Switching to local machine builds..."

sed -i 's|local-build = false;|local-build = true;|g' "$DIR/../pkgs/nixos/dependencies.nix"

export NIXPKGS_ALLOW_UNFREE=1

echo "Building personal machine image..."

nix-build '<nixpkgs/nixos>' -A config.system.build.toplevel -I nixos-config=$DIR/../pkgs/nixos/personal/configuration.nix --no-out-link
