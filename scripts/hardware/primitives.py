# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
# Primitive typed validators shared by hardware collection and intake contracts.
from __future__ import annotations

import re
from dataclasses import dataclass
from typing import TypeAlias

from scripts.support.canonical_json import JsonValue

JsonObject: TypeAlias = dict[str, JsonValue]


@dataclass(frozen=True, slots=True)
class ContractError(Exception):
    """A typed rejection at the hardware-intake trust boundary."""

    reason: str

    def __str__(self) -> str:
        return self.reason


def _keys(value: JsonValue, expected: set[str], label: str) -> JsonObject:
    if not isinstance(value, dict) or set(value) != expected:
        raise ContractError(f"{label} keys")
    return value


def _string(value: JsonValue, pattern: re.Pattern[str], label: str) -> str:
    if not isinstance(value, str) or pattern.fullmatch(value) is None:
        raise ContractError(f"{label} format")
    return value


def _integer(value: JsonValue, label: str, *, positive: bool = False) -> int:
    if not isinstance(value, int) or isinstance(value, bool) or (positive and value <= 0) or value < 0:
        raise ContractError(f"{label} integer")
    return value
