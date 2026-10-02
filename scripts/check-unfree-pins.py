#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
# ─── How to run ───
# python3 -B scripts/check-unfree-pins.py [REPO_PATH]
#
# Read-only: prints pinned vs current for every unfree exception and exits
# non-zero when a pin drifted away from the pinned nixpkgs.
"""Check config/package-exceptions.json against the pinned nixpkgs.

Unfree exceptions are version-exact: when nixpkgs drifts, the first drifted
pin makes every output that includes that package refuse to evaluate
("Refusing to evaluate package ... because it has an unfree license").
This prints pinned vs current for every entry and exits non-zero on drift.

Usage: scripts/check-unfree-pins.py [REPO_PATH]
"""

import json
import pathlib
import subprocess
import sys

ATTR_OVERRIDES = {"idea": "jetbrains.idea", "pycharm": "jetbrains.pycharm"}


def current_version(repo, system, attr):
    expr = (
        f'let pkgs = (builtins.getFlake "{repo}").inputs.nixpkgs'
        f'.legacyPackages."{system}"; in pkgs.lib.getVersion pkgs.{attr}'
    )
    p = subprocess.run(
        ["nix", "eval", "--impure", "--raw", "--expr", expr],
        capture_output=True,
        text=True,
        timeout=180,
    )
    return p.stdout.strip() if p.returncode == 0 else None


def main():
    repo = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    data = json.load(open(repo / "config/package-exceptions.json"))
    rows = {(r["pname"], r["system"]): r["version"] for r in data["unfree"]}
    drift = 0
    for (pname, system), pinned in sorted(rows.items()):
        attr = ATTR_OVERRIDES.get(pname, pname)
        cur = current_version(repo, system, attr)
        state = "ok" if cur == pinned else ("DRIFT" if cur else "eval-error")
        if cur != pinned:
            drift += 1
        print(f"{pname:16} {system:16} pinned={pinned:22} current={cur or '?':22} {state}")
    print(f"\n{drift} drifted pin(s)")
    return 1 if drift else 0


if __name__ == "__main__":
    sys.exit(main())
