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

sed -i 's|local-build = false;|local-build = true;|g' ${DIR}/../pkgs/nixos/dependencies.nix

configurations=(personal-inspiron ats-alderlake ats-pi rankserver-pi)
for configuration in ${configurations[@]}; do
    echo "Checking derivation for configuration: $configuration..."
    nix-build '<nixpkgs/nixos>' -A config.system.build.toplevel -I nixos-config=${DIR}/../pkgs/nixos/configurations/${configuration}.nix --no-out-link --dry-run
    echo "Checks out!"
    echo ""
done

sims=(dronesim)
for sim in ${sims[@]}; do
    echo "Checking derivation for sim environment: $sim..."
    nix-build -A driverInteractive ${DIR}/../pkgs/nixos/sitl-envs/${sim}.nix --no-out-link --dry-run
    echo "Checks out!"
    echo ""
done

# installers=(ats-pi)
# for installer in ${installers[@]}; do
#     echo "Checking derivation for installer: $installer..."
#     nix-build '<nixpkgs/nixos>' -A config.system.build.isoImage -I nixos-config=${DIR}/../pkgs/nixos/installers/${installer}.nix --no-out-link --dry-run
#     echo "Checks out!"
#     echo ""
# done

sed -i 's|local-build = true;|local-build = false;|g' ${DIR}/../pkgs/nixos/dependencies.nix
