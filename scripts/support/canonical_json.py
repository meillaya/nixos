#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
# ─── How to run ───
# python3 -B -I scripts/support/canonical_json.py check FILE
# python3 -B -I scripts/support/canonical_json.py emit FILE

from __future__ import annotations

import json
import math
import os
import stat
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Final, TypeAlias

JsonScalar: TypeAlias = None | bool | int | float | str
JsonValue: TypeAlias = JsonScalar | list["JsonValue"] | dict[str, "JsonValue"]
UTF8_BOM: Final = b"\xef\xbb\xbf"


@dataclass(frozen=True, slots=True)
class CanonicalJsonError(Exception):
    reason: str

    def __str__(self) -> str:
        return self.reason


def _pairs(pairs: list[tuple[str, JsonValue]]) -> dict[str, JsonValue]:
    result: dict[str, JsonValue] = {}
    for key, value in pairs:
        if key in result:
            raise CanonicalJsonError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _reject_constant(value: str) -> JsonValue:
    raise CanonicalJsonError(f"non-finite JSON number: {value}")


def _check_finite(value: JsonValue) -> None:
    match value:
        case float() as number:
            if not math.isfinite(number):
                raise CanonicalJsonError("non-finite JSON number")
        case list() as rows:
            for row in rows:
                _check_finite(row)
        case dict() as mapping:
            for row in mapping.values():
                _check_finite(row)
        case None | bool() | int() | str():
            return


def parse(raw: bytes) -> JsonValue:
    if raw.startswith(UTF8_BOM):
        raise CanonicalJsonError("UTF-8 BOM is forbidden")
    try:
        text = raw.decode("utf-8", errors="strict")
    except UnicodeDecodeError as error:
        raise CanonicalJsonError("input is not UTF-8") from error
    try:
        value: JsonValue = json.loads(
            text,
            object_pairs_hook=_pairs,
            parse_constant=_reject_constant,
        )
    except (json.JSONDecodeError, RecursionError) as error:
        raise CanonicalJsonError(
            f"invalid JSON: {error.msg if isinstance(error, json.JSONDecodeError) else 'too deeply nested'}"
        ) from error
    _check_finite(value)
    return value


def encode(value: JsonValue) -> bytes:
    _check_finite(value)
    try:
        return (
            json.dumps(
                value,
                sort_keys=True,
                separators=(",", ":"),
                ensure_ascii=False,
                allow_nan=False,
            ).encode("utf-8")
            + b"\n"
        )
    except (UnicodeEncodeError, ValueError) as error:
        raise CanonicalJsonError("JSON contains an invalid Unicode scalar") from error


def require_canonical(raw: bytes) -> JsonValue:
    value = parse(raw)
    if raw != encode(value):
        raise CanonicalJsonError(
            "JSON bytes are not canonical sorted compact JSON plus LF"
        )
    return value


def read_regular(path: Path) -> bytes:
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_CLOEXEC", 0)
    try:
        descriptor = os.open(path, flags)
    except OSError as error:
        raise CanonicalJsonError(
            f"cannot safely open {path}: {error.strerror}"
        ) from error
    try:
        metadata = os.fstat(descriptor)
        if not stat.S_ISREG(metadata.st_mode):
            raise CanonicalJsonError(f"not a regular file: {path}")
        chunks: list[bytes] = []
        while chunk := os.read(descriptor, 1024 * 1024):
            chunks.append(chunk)
        return b"".join(chunks)
    finally:
        os.close(descriptor)


def main(argv: list[str]) -> int:
    if len(argv) != 3 or argv[1] not in {"check", "emit"}:
        print("usage: canonical_json.py check|emit FILE", file=sys.stderr)
        return 64
    try:
        raw = read_regular(Path(argv[2]))
        if argv[1] == "check":
            require_canonical(raw)
        else:
            sys.stdout.buffer.write(encode(parse(raw)))
    except CanonicalJsonError as error:
        print(f"INVALID: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
