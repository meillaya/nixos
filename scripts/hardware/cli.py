# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
# ─── How to run ───
# bin/nix-config-hardware-intake collect|create|validate ...
from __future__ import annotations

import sys
from pathlib import Path

from scripts.hardware.collector import read_fixture
from scripts.hardware.contracts import ContractError
from scripts.hardware.intake import apply_intake, build_intake
from scripts.support.canonical_json import CanonicalJsonError, JsonValue, encode, read_regular, require_canonical


def _read(path: str) -> JsonValue:
    try:
        return require_canonical(read_regular(Path(path)))
    except CanonicalJsonError as error:
        raise ContractError("input is not canonical JSON") from error


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        return 64
    try:
        match argv[1]:
            case "collect" if len(argv) == 3:
                sys.stdout.buffer.write(encode(read_fixture(argv[2])))
                return 0
            case "create" if len(argv) == 6:
                result = build_intake(_read(argv[2]), _read(argv[3]), argv[4], argv[5])
                sys.stdout.buffer.write(encode(result))
                return 0
            case "validate" if len(argv) == 4:
                result = apply_intake(_read(argv[2]), _read(argv[3]))
                sys.stdout.buffer.write(encode(result))
                return 0
            case _:
                return 64
    except ContractError as error:
        print(f"INVALID HARDWARE INTAKE: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
