#!/usr/bin/env bash
set -euo pipefail

[[ $# -eq 2 ]] || exit 2
mode=$1
selector=$2
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)

case "$mode:$selector" in
  fixture:F0[1-6]-*|negative:N0[1-8]-*|negative:N1[0-9]-*|negative:N20-*|negative:N2[2-5]-*)
    export PYTHONPATH="$root"
    exec python3 -B "$root/tests/readiness/task7/run_case.py" "$mode" "$selector"
    ;;
  *) exit 2 ;;
esac
