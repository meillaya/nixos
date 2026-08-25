from __future__ import annotations

import copy
import hashlib
from typing import cast

from scripts.hardware.collector import collect_fixture
from scripts.hardware.contracts import declaration_digest, validate_declaration
from scripts.hardware.intake import apply_intake
from scripts.hardware.primitives import ContractError, JsonObject
from scripts.support.canonical_json import JsonValue, encode

def _object(value: JsonValue) -> JsonObject:
    if not isinstance(value, dict):
        raise AssertionError("fixture object expected")
    return cast(JsonObject, value)

def _darwin_declaration(base: JsonObject) -> JsonObject:
    darwin = _object(copy.deepcopy(base))
    darwin.update(
        {
            "hostId": "entropy",
            "target": "darwinConfigurations.entropy",
            "system": "aarch64-darwin",
            "role": "workstation",
            "identity": {"name": "mei", "home": "/Users/mei", "uid": 501, "gid": 20},
            "display": {"scale": {"numerator": 2, "denominator": 1}},
            "cpuVendor": "Apple",
            "firmware": "apple",
            "kernel": "disabled",
            "gpu": "apple-metal",
            "network": "native-darwin",
            "platformExpectations": {
                "kind": "darwin",
                "networkServiceClass": "wifi",
                "requiredTccServices": ["accessibility", "screen"],
                "managedApps": [
                    {"bundleId": "net.kovidgoyal.kitty", "appPathDigest": "1" * 64},
                    {"bundleId": "org.gnu.Emacs", "appPathDigest": "2" * 64},
                ],
                "kitty": {
                    "fontFamily": "FiraCode Nerd Font Mono",
                    "fontDigest": "3" * 64,
                    "configDigest": "4" * 64,
                    "colorDigest": "5" * 64,
                },
                "wallpaperPathDigest": "6" * 64,
                "emacs": {"pathDigest": "7" * 64, "initDigest": "8" * 64, "packageSetDigest": "9" * 64},
            },
        }
    )
    return darwin

def run(case_id: str, source: dict[str, JsonValue], base: dict[str, JsonValue]) -> int:
    if case_id == "N20-model-parity-boundaries":
        candidate = collect_fixture(source)
        invalids: list[JsonObject] = []
        mutations: tuple[tuple[str, JsonValue], ...] = (("identity.home", "/Users/mei"), ("identity.uid", 2_147_483_648), ("identity.gid", 2_147_483_648), ("display.scale", {"numerator": 2, "denominator": 2}), ("location.timeZone", "UTC"), ("location.locale", "C"), ("location.keymap", "us+"), ("cpuVendor", "Apple"))
        for field, value in mutations:
            hostile = _object(copy.deepcopy(candidate))
            if field == "display.scale":
                _object(hostile["display"])["scale"] = value
            elif "." in field:
                parent, key = field.split(".")
                _object(hostile[parent])[key] = value
            else:
                hostile[field] = value
            invalids.append(hostile)
        hostile = _object(copy.deepcopy(candidate))
        hostile["cpuVendor"] = "Apple"
        hostile["devices"] = {"state": "disabled"}
        hostile["capabilities"] = {"state": "disabled"}
        invalids.append(hostile)
        hostile = _object(copy.deepcopy(candidate))
        _object(hostile["publicTrust"])["installAuthorizerPrincipal"] = "mei installer"
        invalids.append(hostile)
        hostile = _object(copy.deepcopy(candidate))
        _object(hostile["publicTrust"])["state"] = "unknown"
        invalids.append(hostile)
        darwin_false = _object(copy.deepcopy(candidate))
        darwin_false.update({"hostId": "entropy", "target": "darwinConfigurations.entropy", "system": "aarch64-darwin", "role": "workstation"})
        invalids.append(darwin_false)
        darwin = _darwin_declaration(base)
        validate_declaration(darwin)
        malformed_darwin = _object(copy.deepcopy(darwin))
        _object(_object(malformed_darwin["platformExpectations"])["kitty"])["fontDigest"] = "z" * 64
        invalids.append(malformed_darwin)
        for hostile in invalids:
            try:
                validate_declaration(hostile)
            except ContractError:
                continue
            return 1
        hostile_source = _object(copy.deepcopy(source))
        _object(hostile_source["storage"])["diskById"] = "nvme-fixture-model-part1"
        try:
            collect_fixture(hostile_source)
        except ContractError:
            return 0
        return 1

    if case_id == "N21-rfc6902-array-add":
        candidate = collect_fixture(source)
        first: JsonObject = {"connector": "DP-0", "i2cLocatorDigest": "a" * 64, "sysfsConnectorDigest": "b" * 64}
        last: JsonObject = {"connector": "DP-2", "i2cLocatorDigest": "c" * 64, "sysfsConnectorDigest": "d" * 64}
        expected = _object(copy.deepcopy(candidate))
        ddc = expected["ddcConnectors"]
        if not isinstance(ddc, list):
            raise AssertionError("fixture DDC list expected")
        ddc.insert(0, first)
        ddc.insert(2, last)
        patch: list[JsonObject] = [{"op": "add", "path": "/ddcConnectors/0", "value": first}, {"op": "add", "path": "/ddcConnectors/2", "value": last}]
        intake: JsonObject = {
            "schemaVersion": 1,
            "hostId": candidate["hostId"],
            "inputDeclarationDigest": declaration_digest(candidate),
            "patch": cast(JsonValue, patch),
            "patchSha256": hashlib.sha256(encode(cast(JsonValue, patch))).hexdigest(),
            "outputDeclarationDigest": declaration_digest(expected),
            "reviewedBy": "fixture-reviewer",
            "appliedAt": "2026-07-16T12:00:00Z",
        }
        if apply_intake(candidate, intake) != expected:
            return 1
        return 0
    return 2
