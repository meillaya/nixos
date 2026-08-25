#!/usr/bin/env bash
set -euo pipefail

[[ $# -eq 2 ]] || exit 2
mode=$1
selector=$2
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)
# The standalone-linux modules now live in the sibling ~/nixos repo.
# Tests that need to inspect those files reference them via $NIXOS_REPO_ROOT
# (defaulting to the sibling directory).
nixos_root=${NIXOS_REPO_ROOT:-$(cd "$root/.." && pwd)/nixos}
cd "$root"

case "$mode:$selector" in
  fixture:F01-capability-projections)
    exec python3 -B tests/readiness/task17/model.py fixture
    ;;
  fixture:F02-service-ownership)
    exec python3 -B tests/readiness/task17/service_static.py "$root"
    ;;
  fixture:F03-standalone-ddc-guidance)
    nix-instantiate --parse "$nixos_root/modules/standalone-linux/packages.nix" >/dev/null
    python3 -B - <<'PY'
from pathlib import Path
import os

nixos_root = os.environ.get("NIXOS_REPO_ROOT", "")
standalone = Path(f"{nixos_root}/modules/standalone-linux/packages.nix").read_text(encoding="utf-8")
packages = Path("modules/linux/packages.nix").read_text(encoding="utf-8")
guidance = Path("docs/service-notes/noctalia-ddc-brightness.md").read_text(encoding="utf-8")
assert "ddcutil" in packages
assert "setup-ddc-brightness" not in standalone
assert "sudo modprobe i2c-dev" in guidance
assert "did not execute or verify" in guidance
PY
    ;;
  negative:N01-capability-applicability)
    exec python3 -B tests/readiness/task17/model.py N01-capability-applicability
    ;;
  negative:N02-duplicate-service-owner)
    tmp=$(mktemp)
    trap 'rm -f "$tmp"' EXIT
    cat modules/nixos/niri.nix >"$tmp"
    printf '\n  services.upower.enable = true;\n' >>"$tmp"
    if python3 -B tests/readiness/task17/service_static.py "$root" --niri "$tmp" >/dev/null 2>&1; then
      exit 1
    fi
    exit 0
    ;;
  negative:N03-cross-platform-service)
    exec python3 -B tests/readiness/task17/model.py N03-cross-platform-service
    ;;
  *) exit 2 ;;
esac
