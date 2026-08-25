#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)
cd "$root"
placeholder=$(printf '%%%s%%' DISK)
volatile=$(printf '/dev/%s' sdX)
! rg -n "$placeholder|$volatile|/dev/vd[a-z]" modules/nixos/disk-config.nix docs/service-notes/nixos-anywhere-disko-install.md
rg -Fq '/dev/disk/by-id/${diskBasename}' modules/nixos/disk-config.nix
rg -Fq 'ERASE' docs/service-notes/nixos-anywhere-disko-install.md
rg -Fq 'physical-install-requires-attended-run' scripts/readiness/task7/installer.py
python3 - <<'PY'
import json
from pathlib import Path
from scripts.readiness.task7.contracts import parse_canonical, validate_tool_sandbox

for name in ("config/install/manifest.schema.json", "config/install/tool-sandbox.json"):
    path = Path(name)
    value = parse_canonical(path.read_bytes())
    assert isinstance(value, dict)
validate_tool_sandbox(parse_canonical(Path("config/install/tool-sandbox.json").read_bytes()))
PY
printf '%s\n' 'TASK 7 STATIC PASS'
