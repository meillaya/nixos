#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)
[[ $# -eq 2 && $1 == fixture || $# -eq 2 && $1 == negative ]] || exit 2
[[ $2 =~ ^[A-Za-z0-9._+-]+$ ]] || exit 2
PYTHONPATH="$root" exec python3 -B "$root/tests/readiness/task7/run_case.py" "$@"
