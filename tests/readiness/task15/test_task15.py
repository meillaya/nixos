# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
from __future__ import annotations

import copy
import json
import os
import pty
import subprocess
import sys
from typing import assert_never
from pathlib import Path

from tests.readiness.task15.extended_negatives import EXTENDED_CASES, run as run_extended_negative
from tests.readiness.task15.fixtures import make_fixture
from scripts.hardware.collector import collect_fixture
from scripts.hardware.contracts import ContractError, declaration_digest
from scripts.hardware.intake import apply_intake, build_intake
from scripts.support.canonical_json import encode


def fixture_case(case_id: str, root: Path) -> int:
    fixture = make_fixture(root)
    match case_id:
        case "F01-deterministic-intake-patch":
            candidate = collect_fixture(fixture.source)
            first = build_intake(fixture.base, candidate, "fixture-reviewer", "2026-07-16T12:00:00Z")
            second = build_intake(fixture.base, candidate, "fixture-reviewer", "2026-07-16T12:00:00Z")
            assert first == second
            assert apply_intake(fixture.base, first) == candidate
            assert first["outputDeclarationDigest"] == declaration_digest(candidate)
        case "F02-separate-host-closures":
            intel = collect_fixture(fixture.source)
            amd_source = copy.deepcopy(fixture.source)
            amd_source["cpu"]["vendor"] = "AuthenticAMD"
            amd = collect_fixture(amd_source)
            assert intel["hostId"] == amd["hostId"]
            assert intel["cpuVendor"] == "GenuineIntel"
            assert amd["cpuVendor"] == "AuthenticAMD"
            assert declaration_digest(intel) != declaration_digest(amd)
        case "F03-network-capability-branches":
            for capability in ("network.ethernet", "network.usb-ethernet", "network.usb-tether", "network.wifi"):
                source = copy.deepcopy(fixture.source)
                source["network"]["capabilities"] = [capability]
                for network_name in ("network.ethernet", "network.usb-ethernet", "network.usb-tether", "network.wifi"):
                    source["capabilities"]["values"][network_name] = {"state": "present"} if network_name == capability else {"state": "absent", "reason": "not-equipped"}
                source["network"]["rows"] = [{"capability": capability, "controllerClass": "02:80:00" if capability == "network.wifi" else "02:00:00", "expectedDriver": "iwlwifi" if capability == "network.wifi" else ("cdc_ncm" if capability == "network.usb-ethernet" else ("cdc_ether" if capability == "network.usb-tether" else "e1000e")), "firmwareExpectation": {"state": "driver-bound-no-load-failure"}}]
                source["network"]["remoteInstall"] = capability != "network.wifi"
                source["capabilities"]["values"]["install.remote"] = {"state": "present"} if capability != "network.wifi" else {"state": "absent", "reason": "deferred"}
                output = collect_fixture(source)
                assert output["remoteInstall"] == (capability != "network.wifi")
                assert output["capabilities"]["values"][capability]["state"] == "present"
            source = copy.deepcopy(fixture.source)
            source["network"]["capabilities"] = ["local-console"]
            for network_name in ("network.ethernet", "network.usb-ethernet", "network.usb-tether", "network.wifi"):
                source["capabilities"]["values"][network_name] = {"state": "absent", "reason": "not-equipped"}
            source["network"]["rows"] = []
            source["network"]["remoteInstall"] = False
            source["capabilities"]["values"]["install.remote"] = {"state": "absent", "reason": "deferred"}
            output = collect_fixture(source)
            assert output["capabilities"]["values"]["recovery.local-console"]["state"] == "present"
        case unreachable:
            assert_never(unreachable)
    return 0


def negative_case(case_id: str, root: Path) -> int:
    fixture = make_fixture(root)
    source = fixture.source
    if case_id in EXTENDED_CASES:
        try:
            return run_extended_negative(case_id, source, fixture.base, root)
        except ContractError:
            return 0
    try:
        match case_id:
            case "N01-pending-denial":
                pending = copy.deepcopy(source)
                pending["cpu"]["vendor"] = "pending"
                collect_fixture(pending)
            case "N02-pointer-allowlist":
                candidate = collect_fixture(source)
                patch = build_intake(fixture.base, candidate, "fixture-reviewer", "2026-07-16T12:00:00Z")
                patch["patch"][0]["path"] = "/identity/name"
                apply_intake(fixture.base, patch)
            case "N03-raw-identifier":
                hostile = copy.deepcopy(source)
                hostile["gpu"]["renderer"] = "raw renderer"
                collect_fixture(hostile)
            case "N04-disk-fact-mutation":
                hostile = copy.deepcopy(source)
                hostile["storage"]["expected"]["sizeBytes"] += 1
                collect_fixture(hostile)
            case "N05-public-key-syntax":
                hostile = copy.deepcopy(source)
                hostile["trust"]["installAuthorizerPublicKey"] = "ssh-rsa raw"
                collect_fixture(hostile)
            case "N06-private-correspondence":
                hostile = copy.deepcopy(source)
                hostile["trust"]["privateKey"] = "fixture-private"
                collect_fixture(hostile)
            case "N07-fingerprint-reuse":
                hostile = copy.deepcopy(source)
                hostile["trust"]["finalHostPublicKey"] = hostile["trust"]["permanentLoginPublicKey"]
                collect_fixture(hostile)
            case "N08-vendor-classification":
                hostile = copy.deepcopy(source)
                hostile["cpu"]["vendor"] = "CentaurHauls"
                collect_fixture(hostile)
            case "N09-wifi-only-remote":
                hostile = copy.deepcopy(source)
                hostile["network"]["capabilities"] = ["network.wifi"]
                hostile["network"]["remoteInstall"] = True
                collect_fixture(hostile)
            case "N10-local-console-only-remote":
                hostile = copy.deepcopy(source)
                hostile["network"]["capabilities"] = ["local-console"]
                hostile["network"]["remoteInstall"] = True
                collect_fixture(hostile)
            case unreachable:
                assert_never(unreachable)
    except ContractError:
        return 0
    return 1


def run_pty(root: Path) -> int:
    fixture = make_fixture(root)
    with __import__("tempfile").TemporaryDirectory(prefix="task15-pty-") as temporary:
        source = Path(temporary) / "source.json"
        source.write_bytes(encode(fixture.source))
        master, slave = pty.openpty()
        process = subprocess.Popen(
            [str(root / "bin/nix-config-hardware-collector"), "--fixture", str(source)],
            stdin=slave,
            stdout=slave,
            stderr=slave,
            env={"PATH": os.environ["PATH"], "PYTHONPATH": str(root), "LC_ALL": "C"},
            close_fds=True,
        )
        os.close(slave)
        try:
            output = os.read(master, 1 << 16)
        finally:
            os.close(master)
        assert process.wait(timeout=5) == 0
    parsed = json.loads(output)
    assert parsed["cpuVendor"] == "GenuineIntel"
    return 0


def main() -> int:
    if len(sys.argv) != 3:
        return 2
    root = Path(__file__).resolve().parents[3]
    with __import__("tempfile").TemporaryDirectory(prefix="task15-") as temporary:
        path = Path(temporary)
        if sys.argv[1] == "fixture":
            return fixture_case(sys.argv[2], path)
        if sys.argv[1] == "negative":
            return negative_case(sys.argv[2], path)
        if sys.argv[1] == "smoke":
            return run_pty(root)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
