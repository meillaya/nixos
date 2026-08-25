#!/usr/bin/env bash
set -euo pipefail

[[ $# -eq 2 ]] || exit 2
mode=$1
selector=$2
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)
# The standalone-linux modules now live in the sibling ~/nixos repo.
nixos_root=${NIXOS_REPO_ROOT:-$(cd "$root/.." && pwd)/nixos}
preflight="$root/scripts/readiness/home_preflight.py"

case "$mode:$selector" in
  fixture:F01-explicit-identity-static)
    exec python3 -B "$root/tests/readiness/task22/identity_static.py" \
      "$nixos_root/modules/standalone-linux/home-manager.nix"
    ;;
  fixture:F02-satisfied-prerequisites)
    output=$(python3 -B "$preflight" --json --fixture \
      "$root/tests/readiness/task22/prerequisites-satisfied.json")
    jq -e '.status == "satisfied" and .owner == "host" and .missing == [] and
      .boundaries == {"activationSudo":false,"decryption":false,"networkTakeover":false,"systemServices":false}' \
      <<<"$output" >/dev/null
    ;;
  negative:N01-missing-prerequisite)
    exec python3 -B "$preflight" --json --fixture \
      "$root/tests/readiness/task22/prerequisites-missing.json"
    ;;
  negative:N02-ambient-identity)
    tmp=$(mktemp)
    trap 'rm -f "$tmp"' EXIT
    sed 's/userName,/userName ? builtins.getEnv "USER",/' \
      "$nixos_root/modules/standalone-linux/home-manager.nix" >"$tmp"
    if python3 -B "$root/tests/readiness/task22/identity_static.py" "$tmp" >/dev/null 2>&1; then
      exit 0
    fi
    exit 1
    ;;
  *) exit 2 ;;
esac
