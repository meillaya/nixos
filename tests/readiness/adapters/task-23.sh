#!/usr/bin/env bash
set -euo pipefail

[[ $# -eq 2 ]] || exit 2
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)
case "$1:$2" in
  fixture:F01-*|fixture:F02-*|negative:N01-*|negative:N0[3-9]-*|negative:N1[0-2]-*)
    export PYTHONPATH="$root"
    exec python3 -B "$root/tests/readiness/task23/run_case.py" "$1" "$2"
    ;;
  *) exit 2 ;;
esac
