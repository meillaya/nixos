from __future__ import annotations

import copy
import os
import subprocess
from collections.abc import Mapping
from pathlib import Path
from typing import cast

from scripts.hardware.collector import collect_fixture
from scripts.hardware.contracts import ContractError, validate_declaration
from scripts.hardware.primitives import JsonObject
from scripts.support.canonical_json import JsonValue, encode
from tests.readiness.task15.model_parity import run as run_model_parity

def _object(value: JsonValue | Mapping[str, JsonValue]) -> JsonObject:
    if not isinstance(value, dict):
        raise AssertionError("fixture object expected")
    return cast(JsonObject, value)


EXTENDED_CASES = frozenset(
    {
        "N11-registered-route-binding",
        "N12-platform-expectations-closure",
        "N13-required-capability-closure",
        "N14-intake-cli-parse",
        "N15-network-capability-duplicates",
        "N16-pending-operational-closure",
        "N17-policy-enum-closure",
        "N18-network-row-capability-correspondence",
        "N19-device-row-closure",
        "N20-model-parity-boundaries",
        "N21-rfc6902-array-add",
    }
)


def run(case_id: str, source: dict[str, JsonValue], base: dict[str, JsonValue], root: Path) -> int:
    if case_id in {"N20-model-parity-boundaries", "N21-rfc6902-array-add"}:
        return run_model_parity(case_id, source, base)
    if case_id == "N11-registered-route-binding":
        candidate = collect_fixture(source)
        for mutation in (
            {"hostId": "remembrance-alias"},
            {"target": "nixosConfigurations.remembrance-alias"},
        ):
            hostile = _object(copy.deepcopy(candidate))
            hostile.update(mutation)
            try:
                validate_declaration(hostile)
            except ContractError:
                continue
            return 1
        return 0

    if case_id == "N12-platform-expectations-closure":
        candidate = collect_fixture(source)
        for expectations in ({"kind": "none", "unexpected": True}, {"kind": "darwin"}):
            hostile = _object(copy.deepcopy(candidate))
            hostile["platformExpectations"] = _object(expectations)
            try:
                validate_declaration(hostile)
            except ContractError:
                continue
            return 1
        return 0

    if case_id == "N13-required-capability-closure":
        candidate = collect_fixture(source)
        for capability in (
            "reboot",
            "rollback",
            "firmware",
            "microcode",
            "recovery.local-console",
            "session",
            "portal-obs",
            "theme-kitty",
        ):
            hostile = _object(copy.deepcopy(candidate))
            capabilities = _object(hostile["capabilities"])
            values = _object(capabilities["values"])
            values[capability] = {"state": "absent", "reason": "deferred"}
            try:
                validate_declaration(hostile)
            except ContractError:
                continue
            return 1
        return 0

    if case_id == "N14-intake-cli-parse":
        candidate = collect_fixture(source)
        base_path = root / "base.json"
        candidate_path = root / "candidate.json"
        base_path.write_bytes(encode(base))
        candidate_path.write_bytes(encode(candidate))
        repo = Path(__file__).resolve().parents[3]
        for index, raw in enumerate((b"{", b"\xef\xbb\xbf{}\n", b'{"schemaVersion":1,"schemaVersion":1}\n')):
            bad_path = root / f"bad-{index}.json"
            bad_path.write_bytes(raw)
            result = subprocess.run(
                [
                    str(repo / "bin/nix-config-hardware-intake"),
                    "create",
                    str(bad_path),
                    str(candidate_path),
                    "fixture-reviewer",
                    "2026-07-16T12:00:00Z",
                ],
                capture_output=True,
                text=True,
                env={"PATH": os.environ["PATH"], "PYTHONPATH": str(repo), "LC_ALL": "C"},
                check=False,
            )
            assert result.returncode == 1
            assert result.stdout == ""
            assert result.stderr.startswith("INVALID HARDWARE INTAKE:")
            assert "Traceback" not in result.stderr
        return 0

    if case_id == "N15-network-capability-duplicates":
        hostile = _object(copy.deepcopy(source))
        network = _object(hostile["network"])
        network["capabilities"] = ["network.ethernet", "network.ethernet"]
        collect_fixture(hostile)
        return 1

    if case_id == "N16-pending-operational-closure":
        candidate = collect_fixture(source)
        mutations = {
            "boot": candidate["boot"],
            "storage": candidate["storage"],
            "publicTrust": candidate["publicTrust"],
            "secretTrust": candidate["secretTrust"],
            "devices": candidate["devices"],
            "capabilities": candidate["capabilities"],
            "ddcConnectors": candidate["ddcConnectors"],
            "remoteInstall": True,
            "firmware": "redistributable",
            "kernel": "nixpkgs-default",
            "gpu": "cpu-only",
            "network": "networkmanager",
        }
        for name, value in mutations.items():
            hostile = _object(copy.deepcopy(base))
            hostile[name] = copy.deepcopy(value)
            try:
                validate_declaration(hostile)
            except ContractError:
                continue
            return 1
        return 0

    if case_id == "N17-policy-enum-closure":
        for name in ("firmware", "kernel", "gpu", "network"):
            hostile = _object(copy.deepcopy(base))
            hostile[name] = "arbitrary-policy"
            try:
                validate_declaration(hostile)
            except ContractError:
                continue
            return 1
        return 0

    if case_id == "N18-network-row-capability-correspondence":
        candidate = collect_fixture(source)
        hostile = _object(copy.deepcopy(candidate))
        devices = _object(hostile["devices"])
        devices["network"] = []
        validate_declaration(hostile)
        return 1

    if case_id == "N19-device-row-closure":
        hostile = _object(copy.deepcopy(source))
        devices = _object(hostile["devices"])
        devices["audio"] = {"state": "present", "unexpected": True}
        collect_fixture(hostile)
        return 1

    return 2
