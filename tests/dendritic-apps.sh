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

for app in build build-switch clean install
do
  test -x "$root/apps/x86_64-linux/$app"
done

# The one-command installer must stay dry-run safe: it prints its plan and
# touches nothing (no work tree, no trust fixture, no disk). The installer
# refuses to run off Linux (its own `uname -s` guard in apps/x86_64-linux/
# install), so the plan is only assertable where it can run at all. The Linux
# host still exercises this block.
if [[ "$(uname -s)" == "Linux" ]]; then
  "$root/apps/x86_64-linux/install" --dry-run > "$tmpdir/install-plan"
  grep -Fq -- '--install-only' "$tmpdir/install-plan"
  grep -Fq -- 'auto_enroll' "$tmpdir/install-plan"
  grep -Fq -- '--extra-files <stage>' "$tmpdir/install-plan"
fi

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
    "install",
    "nh",
    "search-pkgs",
    "update",
    "zix",
], (system, apps)
PY
done

test -f "$root/tools/zix/cli.py"
test -f "$root/tests/zix.sh"

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

# The flake names configurations by host, never by system: a script that asks
# for `darwinConfigurations.aarch64-darwin` or `nixosConfigurations.x86_64-linux`
# requests an attribute Den never creates and dies before the build starts.
if grep -E '(nixosConfigurations|darwinConfigurations)\.(x86_64|aarch64)-(linux|darwin)' \
  "$root/apps/x86_64-linux/build" "$root/apps/x86_64-linux/build-switch" \
  "$root/apps/aarch64-darwin/build" "$root/apps/aarch64-darwin/build-switch"
then
  printf >&2 'app scripts must name a host, not a system-named configuration\n'
  exit 1
fi
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
