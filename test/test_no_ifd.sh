#!/bin/bash

set -euo pipefail

anixdir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

nix-instantiate \
    --option allow-import-from-derivation false \
    --no-gc-warning \
    "$anixdir/test/no-ifd.nix" \
    -A documentation \
    -A sitl-with-generated-defaults \
    >/dev/null
