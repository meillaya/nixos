#!/usr/bin/env bash
# House prose gate: runs tools/check-prose.py over the tree. See that script for
# the rule set it enforces (banned words, banned phrases, no em dashes).
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)

exec python3 "$repo_root/tools/check-prose.py"
