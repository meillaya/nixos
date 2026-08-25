#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)
work=$(mktemp -d "${TMPDIR:-/tmp}/task15-adversarial.XXXXXXXX")
trap 'rm -rf -- "$work"' EXIT HUP INT TERM
PYTHONPATH="$root" python3 -B - "$work/source.json" <<'PY'
from pathlib import Path
import sys
from tests.readiness.task15.fixtures import make_fixture
from scripts.support.canonical_json import encode
path = Path(sys.argv[1])
path.write_bytes(encode(make_fixture(path.parent).source))
PY
out="$work/out.json"
sha256sum "$work/source.json" > "$work/before.sha256"
timeout --signal=TERM --kill-after=1 3 "$root/bin/nix-config-hardware-collector" --fixture "$work/source.json" >"$out"
sha256sum "$work/source.json" > "$work/after.sha256"
diff -u "$work/before.sha256" "$work/after.sha256"
diff -u "$out" <(timeout --signal=TERM --kill-after=1 3 "$root/bin/nix-config-hardware-collector" --fixture "$work/source.json")
printf '\xef\xbb\xbf{}\n' > "$work/bom.json"
if "$root/bin/nix-config-hardware-collector" --fixture "$work/bom.json" >/dev/null 2>&1; then exit 1; fi
printf '{"schemaVersion":1,"schemaVersion":1}\n' > "$work/duplicate.json"
if "$root/bin/nix-config-hardware-collector" --fixture "$work/duplicate.json" >/dev/null 2>&1; then exit 1; fi
cp "$work/source.json" "$work/marker.json"
printf '\nTASK 15 FIXTURE PASS\n' >> "$work/marker.json"
if "$root/bin/nix-config-hardware-collector" --fixture "$work/marker.json" >/dev/null 2>&1; then exit 1; fi
printf '%s\n' 'TASK 15 ADVERSARIAL PASS'
