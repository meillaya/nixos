#!/usr/bin/env bash
set -euo pipefail

[[ $# -eq 2 ]] || exit 2
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)
exec "$root/tests/readiness/task22/run-case.sh" "$1" "$2"
