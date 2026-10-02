#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

# 1. The CLI must be usable without a repository (help and version only).
python3 "$root/tools/zix/cli.py" --version > /dev/null
for cmd in doctor check switch update follows flakes pkg sandbox vm bin wrap grail input
do
  python3 "$root/tools/zix/cli.py" "$cmd" --help > /dev/null
done

# 2. Unit + fixture tests. Offline: nix and mvs are stubbed inside.
cd "$root"
python3 -m unittest discover -s tools/zix/tests -q

# 3. Offline smoke runs against this repository. Every one of them is a
#    read-only or dry-run operation, so step 4 can prove nothing moved.
status_before=$(git status --porcelain 2>/dev/null || true)
python3 tools/zix/cli.py --repo "$root" pkg list > /dev/null
python3 tools/zix/cli.py --repo "$root" pkg where hydralauncher > /dev/null
python3 tools/zix/cli.py --repo "$root" input ls > /dev/null
python3 tools/zix/cli.py --repo "$root" --dry-run pkg add zix-smoke-package > /dev/null
python3 tools/zix/cli.py --repo "$root" --dry-run pkg rm htop > /dev/null

# 4. Nothing above may have changed the working tree.
status_after=$(git status --porcelain 2>/dev/null || true)
if [ "$status_before" != "$status_after" ]
then
  printf >&2 'zix-check: dry runs changed the working tree:\n'
  printf '%s\n' "$status_after" >&2
  exit 1
fi

printf '%s\n' 'zix-check=PASS'
