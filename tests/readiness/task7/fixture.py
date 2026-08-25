from __future__ import annotations

import hashlib
import os
from pathlib import Path
from typing import Any

from scripts.readiness.task7.contracts import canonical


BOOT_ID = "12345678-1234-4123-8123-123456789abc"


def write_topology(root: Path, *, link_target: str = "../../nvme0n1", partition: bool = False, mounted: bool = False, swap: bool = False, holders: list[str] | None = None, parent: str = "/sys/devices/pci0000:00/nvme0") -> Path:
    disk = "/dev/disk/by-id/fixture-disk"
    row = {
        "byId": disk,
        "canonicalSysfsPath": "/sys/devices/pci0000:00/nvme0",
        "holders": sorted(holders or []),
        "logicalSectorBytes": 512,
        "major": 259,
        "minor": 0,
        "modelSha256": "1" * 64,
        "parentSysfsPath": parent,
        "partition": partition,
        "path": "/dev/nvme0n1",
        "serialSha256": "2" * 64,
        "sizeBytes": 1000204886016,
        "swap": swap,
        "mounted": mounted,
    }
    payload = {"devices": [row], "links": {disk: {"kind": "symlink", "target": link_target}}}
    path = root / "topology.json"
    path.write_bytes(canonical(payload))
    path.chmod(0o600)
    return path


def write_sandbox(root: Path) -> Path:
    path = Path(__file__).resolve().parents[3] / "config/install/tool-sandbox.json"
    destination = root / "tool-sandbox.json"
    destination.write_bytes(path.read_bytes())
    destination.chmod(0o600)
    return destination
