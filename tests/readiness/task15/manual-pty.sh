#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)
work=$(mktemp -d "${TMPDIR:-/tmp}/task15-pty.XXXXXXXX")
trap 'rm -rf -- "$work"' EXIT HUP INT TERM
PYTHONPATH="$root" python3 -B - "$work/source.json" <<'PY'
from pathlib import Path
import sys
from tests.readiness.task15.fixtures import make_fixture
from scripts.support.canonical_json import encode
out = Path(sys.argv[1])
out.write_bytes(encode(make_fixture(out.parent).source))
PY
script -qec "env -i PATH='$PATH' PYTHONPATH='$root' '$root/bin/nix-config-hardware-collector' --fixture '$work/source.json'" /dev/null >"$work/pty.out" 2>"$work/pty.err"
grep -Fq '"cpuVendor":"GenuineIntel"' "$work/pty.out"
printf '%s\n' 'TASK 15 PTY COLLECTOR PASS'
