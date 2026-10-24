#!/bin/bash

set -eo pipefail

echo "Building build environments..."

python3 "$(dirname "${BASH_SOURCE[0]}")/ci_build.py" --envs
