#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/dendritic-apps.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT

awk '
  /<<'\''PY'\''$/ { capture = 1; next }
  capture && /^PY$/ { exit }
  capture { print }
' "$root/modules/flake/apps.nix" > "$tmpdir/linux-home-sources.py"

test -s "$tmpdir/linux-home-sources.py"
python3 -m py_compile "$tmpdir/linux-home-sources.py"

grep -Fq 'exec ${self}/apps/${system}/${scriptName} "$@"' \
  "$root/modules/flake/apps.nix"

for app in build build-switch clean
do
  test -x "$root/apps/x86_64-linux/$app"
done

for system in x86_64-linux; do
  app_names=$(nix eval --impure --json --expr \
    "builtins.attrNames (builtins.getFlake \"path:$root\").apps.$system")
  python3 - "$system" "$app_names" <<'PY'
import json
import sys

system = sys.argv[1]
apps = json.loads(sys.argv[2])
assert apps == [
    "build",
    "build-switch",
    "clean",
    "home-news",
    "home-switch",
    "nh",
    "search-pkgs",
    "update",
], (system, apps)
PY
done

if grep -R -E \
  'nixos-rebuild[[:space:]]+(switch|boot)|nix-collect-garbage|--delete-older-than|--install-bootloader' \
  "$root/apps/x86_64-linux/build" \
  "$root/apps/aarch64-darwin/build"
then
  echo 'evaluation Linux or Darwin app scripts retain a boot-mutating path' >&2
  exit 1
fi

# nixos does not include the standalone Home Manager aspect chain
# (the standalone homes live in ~/nixos), so the standalone impurity
# checks no longer apply here.
test -d "$root/apps/aarch64-darwin"
test ! -L "$root/apps/aarch64-darwin"
for app in build build-switch clean
do
  test -x "$root/apps/aarch64-darwin/$app"
done
test ! -e "$root/apps/x86_64-darwin"

app_systems=$(nix eval --impure --json --expr \
  "builtins.attrNames (builtins.getFlake \"path:$root\").apps")
python3 - "$app_systems" <<'PY'
import json
import sys

systems = json.loads(sys.argv[1])
assert "x86_64-linux" in systems
assert "aarch64-darwin" in systems
assert "x86_64-darwin" not in systems
PY

printf '%s\n' 'dendritic-apps=PASS'
