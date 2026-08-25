#!/usr/bin/env python3
"""Read-only prerequisite report for standalone Home Manager adoption.

The host owns system services and secret provisioning. This probe intentionally
reports those boundaries instead of trying to repair them.
"""
from __future__ import annotations

import argparse
import json
import shutil
import stat
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Final, Literal, NoReturn

SCHEMA_VERSION: Final = 1
Status = Literal["satisfied", "missing"]
type JsonValue = str | int | float | bool | None | list[str] | list[JsonValue] | dict[str, JsonValue]

PREREQUISITES: Final = (
    ("nix", ("nix",)),
    ("portals", ("xdg-desktop-portal",)),
    ("keyring", ("gnome-keyring", "gnome-keyring-daemon")),
    ("polkit", ("pkexec", "polkit-kde-authentication-agent-1")),
    ("pipewire", ("pipewire", "pw-cli")),
    ("gpu-gaming", ("vulkaninfo", "gamemoderun", "steam")),
    ("system", ("systemctl",)),
    ("i2c", ("ddcutil", "i2cdetect")),
)
NAMES: Final = tuple(sorted(name for name, _ in PREREQUISITES))


@dataclass(frozen=True, slots=True)
class Prerequisite:
    name: str
    status: Status


def fail(message: str) -> NoReturn:
    print(f"nix-config-home-preflight: {message}", file=sys.stderr)
    raise SystemExit(2)


def canonical(value: JsonValue) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def parse_status(value: str) -> Status:
    if value == "satisfied":
        return "satisfied"
    if value == "missing":
        return "missing"
    fail("fixture prerequisite status invalid")


def read_fixture(path: Path) -> tuple[Prerequisite, ...]:
    try:
        metadata = path.lstat()
        raw = path.read_bytes()
        decoded = json.loads(raw)
    except (OSError, json.JSONDecodeError) as error:
        fail(f"fixture invalid: {error}")
    if not stat.S_ISREG(metadata.st_mode) or stat.S_ISLNK(metadata.st_mode):
        fail("fixture must be a regular non-symlink file")
    if not isinstance(decoded, dict) or set(decoded) != {"schemaVersion", "prerequisites"}:
        fail("fixture schema mismatch")
    if decoded["schemaVersion"] != SCHEMA_VERSION or not isinstance(decoded["prerequisites"], list):
        fail("fixture schema mismatch")

    rows: list[Prerequisite] = []
    for raw_row in decoded["prerequisites"]:
        if not isinstance(raw_row, dict) or set(raw_row) != {"name", "status"}:
            fail("fixture row shape mismatch")
        name = raw_row["name"]
        status = raw_row["status"]
        if not isinstance(name, str) or name not in NAMES or not isinstance(status, str):
            fail("fixture prerequisite row invalid")
        rows.append(Prerequisite(name, parse_status(status)))

    if tuple(row.name for row in rows) != NAMES:
        fail("fixture prerequisite rows must be sorted and complete")
    if raw != canonical(decoded):
        fail("fixture must be canonical JSON")
    return tuple(rows)


def live_rows() -> tuple[Prerequisite, ...]:
    return tuple(
        Prerequisite(name, "satisfied" if any(shutil.which(candidate) for candidate in candidates) else "missing")
        for name, candidates in PREREQUISITES
    )


def report(rows: tuple[Prerequisite, ...]) -> dict[str, JsonValue]:
    missing = [row.name for row in rows if row.status == "missing"]
    return {
        "boundaries": {
            "activationSudo": False,
            "decryption": False,
            "networkTakeover": False,
            "systemServices": False,
        },
        "missing": missing,
        "owner": "host",
        "prerequisites": [{"name": row.name, "status": row.status} for row in rows],
        "schemaVersion": SCHEMA_VERSION,
        "status": "missing" if missing else "satisfied",
    }


def main() -> int:
    parser = argparse.ArgumentParser(prog="nix-config-home-preflight")
    parser.add_argument("--fixture", type=Path)
    parser.add_argument("--json", action="store_true")
    arguments = parser.parse_args()
    result = report(read_fixture(arguments.fixture) if arguments.fixture else live_rows())
    sys.stdout.buffer.write(canonical(result))
    return 0 if result["status"] == "satisfied" else 1


if __name__ == "__main__":
    raise SystemExit(main())
