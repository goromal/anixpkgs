#!/bin/bash

set -eo pipefail

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

export NIXPKGS_ALLOW_UNFREE=1
export NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1

configurations=(personal-inspiron rankserver-pi)
for configuration in ${configurations[@]}; do
    echo "Checking derivation for configuration: $configuration..."
    nix-build '<nixpkgs/nixos>' -A config.system.build.toplevel -I nixos-config=${DIR}/../pkgs/nixos/configurations/${configuration}.nix --no-out-link --dry-run
    echo "Checks out!"
    echo ""
done

installers=(ats)
for installer in ${installers[@]}; do
    echo "Checking derivation for installer: $installer..."
    nix-build '<nixpkgs/nixos>' -A config.system.build.isoImage -I nixos-config=${DIR}/../pkgs/nixos/installers/]${installer}.nix --no-out-link --dry-run
    echo "Checks out!"
    echo ""
done
