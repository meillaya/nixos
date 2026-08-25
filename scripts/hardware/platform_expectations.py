# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
# Closed platform expectations validators shared by hardware declaration checks.
from __future__ import annotations

import re
from typing import Final

from scripts.hardware.primitives import ContractError, JsonObject, _keys, _string
from scripts.support.canonical_json import JsonValue

_SHA256: Final = re.compile(r"^[0-9a-f]{64}$")
_BUNDLE_ID: Final = re.compile(r"^[A-Za-z0-9][A-Za-z0-9.-]{1,254}$")
_TCC_SERVICE: Final = re.compile(r"^[A-Za-z0-9._-]{1,128}$")
_PRINTABLE: Final = re.compile(r"^[ -~]{1,128}$")


def _sha(value: JsonValue, label: str) -> str:
    return _string(value, _SHA256, label)


def _sorted_unique_strings(value: JsonValue, pattern: re.Pattern[str], label: str) -> list[str]:
    if not isinstance(value, list) or any(not isinstance(item, str) for item in value):
        raise ContractError(f"{label} list")
    result = [item for item in value if isinstance(item, str)]
    if result != sorted(result) or len(set(result)) != len(result) or any(pattern.fullmatch(item) is None for item in result):
        raise ContractError(f"{label} values")
    return result


def _sorted_unique_rows(value: JsonValue, key: str, label: str) -> list[JsonObject]:
    if not isinstance(value, list) or any(not isinstance(item, dict) for item in value):
        raise ContractError(f"{label} list")
    rows = [item for item in value if isinstance(item, dict)]
    names = [_string(row[key], re.compile(r"^.+$"), f"{label}.{key}") if key in row else "" for row in rows]
    if names != sorted(names) or len(set(names)) != len(names):
        raise ContractError(f"{label} ordering")
    return rows


def validate_platform_expectations(value: JsonValue) -> JsonObject:
    if not isinstance(value, dict):
        raise ContractError("platformExpectations object")
    kind = value.get("kind")
    if kind == "none":
        return _keys(value, {"kind"}, "platformExpectations")
    if kind != "darwin":
        raise ContractError("platformExpectations kind")
    row = _keys(value, {"kind", "networkServiceClass", "requiredTccServices", "managedApps", "kitty", "wallpaperPathDigest", "emacs"}, "platformExpectations")
    if row["networkServiceClass"] not in {"wifi", "ethernet", "usb-ethernet", "tether"}:
        raise ContractError("platformExpectations network service")
    _sorted_unique_strings(row["requiredTccServices"], _TCC_SERVICE, "platformExpectations.requiredTccServices")
    apps = _sorted_unique_rows(row["managedApps"], "bundleId", "platformExpectations.managedApps")
    for app in apps:
        app_row = _keys(app, {"bundleId", "appPathDigest"}, "platformExpectations.managedApp")
        _string(app_row["bundleId"], _BUNDLE_ID, "platformExpectations.bundleId")
        _sha(app_row["appPathDigest"], "platformExpectations.appPathDigest")
    kitty = _keys(row["kitty"], {"fontFamily", "fontDigest", "configDigest", "colorDigest"}, "platformExpectations.kitty")
    _string(kitty["fontFamily"], _PRINTABLE, "platformExpectations.fontFamily")
    _sha(kitty["fontDigest"], "platformExpectations.fontDigest")
    _sha(kitty["configDigest"], "platformExpectations.configDigest")
    _sha(kitty["colorDigest"], "platformExpectations.colorDigest")
    _sha(row["wallpaperPathDigest"], "platformExpectations.wallpaperPathDigest")
    emacs = _keys(row["emacs"], {"pathDigest", "initDigest", "packageSetDigest"}, "platformExpectations.emacs")
    _sha(emacs["pathDigest"], "platformExpectations.emacs.pathDigest")
    _sha(emacs["initDigest"], "platformExpectations.emacs.initDigest")
    _sha(emacs["packageSetDigest"], "platformExpectations.emacs.packageSetDigest")
    return row
