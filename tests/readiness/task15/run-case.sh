#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)
[[ $# -eq 2 ]] || exit 2
cd "$root"
export PYTHONPATH="$root"
exec python3 -B tests/readiness/task15/test_task15.py "$1" "$2"
