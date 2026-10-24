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

sed -i 's|local-build = false;|local-build = true;|g' ${DIR}/../pkgs/nixos/dependencies.nix
configurations=(personal-inspiron personal-panasonic personal-dell ats-alderlake ats-pi jetpack-orin-nx jetpack-orin-agx drone-obc-sitl)
declare -A flake_keys=(
    [personal-inspiron]="atorgesen-inspiron"
    [personal-panasonic]="atorgesen-panasonic"
    [personal-dell]="atorgesen-dell"
    [ats-alderlake]="ats"
    [ats-pi]="ats-pi"
    [jetpack-orin-nx]="jetson-orin-nx"
    [jetpack-orin-agx]="jetson-orin-agx"
    [drone-obc-sitl]="drone-obc-sitl"
)
declare -A installer_artifacts=(
    [installer-personal]="isoImage"
    # [installer-ats-pi]="sdImage"
    [installer-jetpack]="isoImage"
)
sims=(dronesim)

# Each check is an independent, eval-bound dry run peaking at ~2-3.5 GB, so
# run a few at once (MACHINE_CHECK_JOBS) and print each log as one block.
checks=()
for configuration in "${configurations[@]}"; do
    flake_key="${flake_keys[$configuration]}"
    checks+=("configuration: $configuration|nix build ${DIR}/..#nixosConfigurations.${flake_key}.config.system.build.toplevel --no-link --dry-run --impure --show-trace")
done
for sim in "${sims[@]}"; do
    checks+=("sim environment: $sim|nix-build -A driverInteractive ${DIR}/../pkgs/nixos/sitl-envs/${sim}.nix --no-out-link --dry-run --show-trace")
done
for installer in "${!installer_artifacts[@]}"; do
    artifact=${installer_artifacts[$installer]}
    checks+=("installer: $installer ($artifact)|nix build ${DIR}/..#nixosConfigurations.${installer}.config.system.build.${artifact} --no-link --dry-run --impure --show-trace")
done

logdir=$(mktemp -d)
run_check() {
    local idx=$1 label=${2%%|*} cmd=${2#*|}
    if $cmd >"$logdir/$idx.log" 2>&1; then
        echo "ok" >"$logdir/$idx.status"
    else
        echo "FAILED" >"$logdir/$idx.status"
    fi
    echo "$(cat "$logdir/$idx.status"): $label"
}
export -f run_check
export logdir NIXPKGS_ALLOW_UNFREE NIXPKGS_ALLOW_INSECURE NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM
for i in "${!checks[@]}"; do
    printf '%s\0%s\0' "$i" "${checks[$i]}"
done | xargs -0 -n 2 -P "${MACHINE_CHECK_JOBS:-3}" bash -c 'run_check "$@"' _

failed=0
for i in "${!checks[@]}"; do
    label=${checks[$i]%%|*}
    status=$(cat "$logdir/$i.status" 2>/dev/null || echo "FAILED")
    [[ -n "$GITHUB_ACTIONS" ]] && echo "::group::$status: $label"
    echo "Checking derivation for $label..."
    cat "$logdir/$i.log"
    if [[ "$status" == "ok" ]]; then
        echo "Checks out!"
    else
        echo "FAILED: $label"
        failed=1
    fi
    [[ -n "$GITHUB_ACTIONS" ]] && echo "::endgroup::"
    echo ""
done
rm -rf "$logdir"
exit $failed
