#!/bin/bash

set -eo pipefail

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

on_exit() {
    echo "Cleaning up..."
    sed -i 's|local-build = true;|local-build = false;|g' ${DIR}/../pkgs/nixos/dependencies.nix
}

trap on_exit ERR SIGINT EXIT

export NIXPKGS_ALLOW_UNFREE=1
export NIXPKGS_ALLOW_INSECURE=1
export NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1

# In CI, the flake source is copied to the Nix store as a read-only snapshot, so
# builtins.storePath (used by flake-compat inside default.nix) cannot resolve it.
# local-build=true is only useful for local development where the source is already
# a store path. The NixOS module code is always from the local flake source.
if [ -z "${GITHUB_ACTIONS:-}" ]; then
    sed -i 's|local-build = false;|local-build = true;|g' ${DIR}/../pkgs/nixos/dependencies.nix
fi

# Map from display name to flake nixosConfigurations key
# jetpack-orin-nx is excluded until jetpack-nixos supports nixpkgs 26.05
# (modules/services-modular uses lib/services/lib.nix which was removed in 26.05)
configurations=(personal-inspiron personal-panasonic personal-dell ats-alderlake ats-pi)
declare -A flake_keys=(
    [personal-inspiron]="atorgesen-inspiron"
    [personal-panasonic]="atorgesen-panasonic"
    [personal-dell]="atorgesen-dell"
    [ats-alderlake]="ats"
    [ats-pi]="ats-pi"
)
for configuration in "${configurations[@]}"; do
    flake_key="${flake_keys[$configuration]}"
    echo
    echo
    echo "Checking derivation for configuration: $configuration..."
    nix build "${DIR}/..#nixosConfigurations.${flake_key}.config.system.build.toplevel" --no-link --dry-run --impure --show-trace
    echo "Checks out!"
    echo ""
done

sims=(dronesim)
for sim in ${sims[@]}; do
    echo "Checking derivation for sim environment: $sim..."
    nix-build -A driverInteractive ${DIR}/../pkgs/nixos/sitl-envs/${sim}.nix --no-out-link --dry-run --show-trace
    echo "Checks out!"
    echo ""
done

declare -A installer_artifacts=(
    [installer-personal]="isoImage"
    # [installer-ats-pi]="sdImage"
    [installer-jetpack]="isoImage"
)
for installer in "${!installer_artifacts[@]}"; do
    artifact=${installer_artifacts[$installer]}
    echo "Checking derivation for installer: $installer ($artifact)..."
    nix build ${DIR}/..#nixosConfigurations.${installer}.config.system.build.${artifact} --no-link --dry-run --impure --show-trace
    echo "Checks out!"
    echo ""
done
