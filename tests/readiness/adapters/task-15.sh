#!/usr/bin/env bash
set -euo pipefail

[[ $# -eq 2 ]] || exit 2
mode=$1
selector=$2
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)
runner="$root/tests/readiness/task15/run-case.sh"

case "$mode:$selector" in
  fixture:F01-*|fixture:F02-*|fixture:F03-*)
    "$runner" "$mode" "$selector"
    if [[ $selector == F03-network-capability-branches ]]; then
      "$root/tests/readiness/task15/manual-pty.sh"
      "$root/tests/readiness/task15/adversarial.sh"
    fi
    ;;
  negative:N0[1-9]-*|negative:N1[0-9]-*|negative:N2[01]-*)
    if "$runner" "$mode" "$selector"; then
      exit 1
    fi
    exit 0
    ;;
  *) exit 2 ;;
esac
