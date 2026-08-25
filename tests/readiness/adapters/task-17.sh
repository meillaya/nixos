#!/usr/bin/env bash
set -euo pipefail

[[ $# -eq 2 ]] || exit 2
mode=$1
selector=$2
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)
runner="$root/tests/readiness/task17/run-case.sh"

case "$mode:$selector" in
  fixture:F0[1-3]-*)
    exec "$runner" "$mode" "$selector"
    ;;
  negative:N0[1-3]-*)
    if "$runner" "$mode" "$selector"; then
      exit 1
    fi
    exit 0
    ;;
  *) exit 2 ;;
esac
