#!/usr/bin/env bash
set -euo pipefail

repo_root=${DENDRITIC_POLICY_REPO_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}
policy_file="$repo_root/lib/nixpkgs.nix"
exceptions_file="$repo_root/config/package-exceptions.json"
shared_packages_file="$repo_root/modules/shared/packages.nix"

production_derivation_sources=("$repo_root/flake.nix")
while IFS= read -r -d '' source; do
  case "$source" in
    "$repo_root/modules/flake/apps.nix"|"$repo_root/modules/flake/checks.nix")
      continue
      ;;
  esac
  production_derivation_sources+=("$source")
done < <(find "$repo_root/lib" "$repo_root/modules" -type f -name '*.nix' -print0)

if grep -En \
  '(^|[^[:alnum:]_])(runCommand(Local)?|mkDerivation|build[A-Z][[:alnum:]_]*)([^[:alnum:]_]|$)' \
  "${production_derivation_sources[@]}"; then
  printf >&2 'retired standalone package recipes must not return to production modules\n'
  exit 1
fi

if grep -R -E 'nixpkgsSearch[[:space:]]*=|setup-ddc-brightness[[:space:]]*=|nix-config-home-preflight' \
  "$repo_root/modules"; then
  printf >&2 'redundant production helper derivation returned\n'
  exit 1
fi

if grep -Eq 'allowBroken[[:space:]]*=' "$policy_file"; then
  printf >&2 'package policy must not define allowBroken in %s\n' "$policy_file"
  exit 1
fi

if grep -Eq 'permittedInsecurePackages[[:space:]]*=' "$policy_file"; then
  printf >&2 'package policy must not define permittedInsecurePackages in %s\n' "$policy_file"
  exit 1
fi

if grep -Eq 'allowUnfree[[:space:]]*=[[:space:]]*true[[:space:]]*;' "$policy_file"; then
  printf >&2 'package policy must not rely on allowUnfree = true in %s\n' "$policy_file"
  exit 1
fi

if ! grep -Eq 'allowUnfreePredicate[[:space:]]*=' "$policy_file"; then
  printf >&2 'package policy must expose an allowUnfreePredicate in %s\n' "$policy_file"
  exit 1
fi

if grep -Eq 'nixosRenderDocsCompatOverlay|nixos-render-docs[[:space:]]*=' "$policy_file"; then
  printf >&2 'package policy must not define a custom nixos-render-docs overlay in %s\n' "$policy_file"
  exit 1
fi

if ! grep -Eq '\(import inputs[.]emacs-overlay\)' "$policy_file"; then
  printf >&2 'package policy must keep the upstream emacs overlay in %s\n' "$policy_file"
  exit 1
fi

if ! python - "$exceptions_file" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    exceptions = json.load(source)

retired = [
    row
    for rows in exceptions.values()
    if isinstance(rows, list)
    for row in rows
    if row.get("system") == "x86_64-darwin"
    or "x86_64-darwin" in row.get("output", "")
]
if retired:
    print("package exceptions must not contain x86_64-darwin rows", file=sys.stderr)
    for row in retired:
        print(f'  {row.get("output")}: {row.get("pname")}', file=sys.stderr)
    raise SystemExit(1)
PY
then
  exit 1
fi

if ! python - "$shared_packages_file" <<'PY'
import re
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    packages = source.read()

declaration = re.compile(
    r"^[ \t]*(?:pkgs\.)?(rustc|cargo|rust-analyzer|rustup)[ \t]*(?:#.*)?$",
    re.MULTILINE,
)
counts = {
    package: 0
    for package in ("rustc", "cargo", "rust-analyzer", "rustup")
}
for package in declaration.findall(packages):
    counts[package] += 1

standalone = ("rustc", "cargo", "rust-analyzer")
if counts["rustup"] and any(counts[package] for package in standalone):
    print(
        "rustup must not coexist with standalone Rust command providers "
        f"in {sys.argv[1]}",
        file=sys.stderr,
    )
    raise SystemExit(1)

invalid = [package for package in standalone if counts[package] != 1]
if invalid:
    print(
        "expected exactly one Nix-managed declaration for each of "
        f"rustc, cargo, and rust-analyzer in {sys.argv[1]}; got {counts}",
        file=sys.stderr,
    )
    raise SystemExit(1)
PY
then
  exit 1
fi

export HOME="${TMPDIR:-/tmp}/package-policy-home"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
mkdir -p "$HOME" "$XDG_STATE_HOME" "$XDG_DATA_HOME"
export NIX_CONFIG="${NIX_CONFIG:-} experimental-features = nix-command flakes"
probe_expr='let
  repoFlake = builtins.getFlake ("path:" + toString ./.);
  envNixpkgs = builtins.getEnv "DENDRITIC_NIXPKGS_FLAKE";
  envEmacsOverlay = builtins.getEnv "DENDRITIC_EMACS_OVERLAY_FLAKE";
  policyInputs = if envNixpkgs != "" && envEmacsOverlay != "" then {
    nixpkgs = builtins.getFlake ("path:" + envNixpkgs);
    "emacs-overlay" = builtins.getFlake ("path:" + envEmacsOverlay);
  } else repoFlake.inputs;
  policy = import ./lib/nixpkgs.nix { inputs = policyInputs; };
  pkgs = policy.mkPkgs "x86_64-linux";
in {
  allowed = builtins.tryEval pkgs.google-chrome.drvPath;
  obsidianAllowed = builtins.tryEval pkgs.obsidian.drvPath;
  blocked = builtins.tryEval pkgs.steam.drvPath;
  overlayCount = builtins.length policy.overlays;
}'
probe_json=$(cd "$repo_root" && nix eval --offline --impure --json --expr "$probe_expr")

allowed_success=$(printf '%s' "$probe_json" | python -c 'import json,sys; print(str(json.load(sys.stdin)["allowed"]["success"]).lower())')
blocked_success=$(printf '%s' "$probe_json" | python -c 'import json,sys; print(str(json.load(sys.stdin)["blocked"]["success"]).lower())')
obsidian_allowed_success=$(printf '%s' "$probe_json" | python -c 'import json,sys; print(str(json.load(sys.stdin)["obsidianAllowed"]["success"]).lower())')
overlay_count=$(printf '%s' "$probe_json" | python -c 'import json,sys; print(json.load(sys.stdin)["overlayCount"])')

if [[ "$allowed_success" != true ]]; then
  printf >&2 'expected allowed unfree package to expose drvPath, got: %s\n' "$probe_json"
  exit 1
fi

if [[ "$obsidian_allowed_success" != true ]]; then
  printf >&2 'expected requested Obsidian package to expose drvPath, got: %s\n' "$probe_json"
  exit 1
fi

if [[ "$blocked_success" != false ]]; then
  printf >&2 'expected blocked unfree package to fail drvPath probe, got: %s\n' "$probe_json"
  exit 1
fi

if [[ "$overlay_count" -lt 1 ]]; then
  printf >&2 'expected at least the upstream emacs overlay, got: %s\n' "$probe_json"
  exit 1
fi

printf 'package-policy-source=PASS\n'
printf 'package-policy-probe=PASS\n'
