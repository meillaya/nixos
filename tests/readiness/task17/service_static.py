"""Static checks for the current Task 17 partial service ownership."""
from __future__ import annotations

import argparse
import re
from pathlib import Path


OPTIONS = (
    "hardware.bluetooth.enable",
    "services.upower.enable",
    "services.power-profiles-daemon.enable",
)


def assignments(source: str, option: str) -> list[str]:
    pattern = re.compile(rf"^\s*{re.escape(option)}\s*=", re.MULTILINE)
    return pattern.findall(source)


def check(root: Path, niri: Path | None = None) -> None:
    current_niri = root / "modules/nixos/niri.nix"
    sources = []
    for path in root.glob("modules/**/*.nix"):
        source_path = niri if niri is not None and path == current_niri else path
        sources.append((path, source_path.read_text(encoding="utf-8")))
    for option in OPTIONS:
        counts = [(path, len(assignments(source, option))) for path, source in sources]
        owners = [path for path, count in counts if count]
        assert owners, f"{option}: no explicit declaration"
        assert all(count <= 1 for _, count in counts), f"{option}: repeated declaration in one module"
    pipewire_counts = [
        (path, len(re.findall(r"^\s*services\.pipewire\s*=", source, re.MULTILINE)))
        for path, source in sources
    ]
    assert any(count for _, count in pipewire_counts), "services.pipewire: no explicit declaration"
    assert all(count <= 1 for _, count in pipewire_counts), "services.pipewire: repeated declaration in one module"

    packages = (root / "modules/linux/packages.nix").read_text(encoding="utf-8")
    assert "ddcutil" in packages
    assert "setup-ddc-brightness" not in packages

    guidance = (root / "docs/service-notes/noctalia-ddc-brightness.md").read_text(
        encoding="utf-8"
    )
    assert "sudo modprobe i2c-dev" in guidance
    assert "did not execute or verify" in guidance


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("--niri", type=Path)
    args = parser.parse_args()
    check(args.root, args.niri)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
