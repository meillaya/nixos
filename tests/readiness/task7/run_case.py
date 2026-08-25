#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

from scripts.readiness.task7.contracts import ContractError, canonical, parse_canonical, resolve_fixture, validate_manifest, validate_tool_sandbox
from scripts.readiness.task7.journal import make_journal, promote_staging, reject_resume_from_inflight, save_journal
from scripts.readiness.task7.sandbox import ToolBroker
from scripts.readiness.task7.identity import activate_identity, stage_identity
from tests.readiness.task7.fixture import BOOT_ID, write_sandbox, write_topology

ROOT = Path(__file__).resolve().parents[3]


def expect_rejected(function) -> int:
    try:
        function()
    except (ContractError, AssertionError, OSError, subprocess.SubprocessError):
        return 1
    return 0


def make_manifest() -> dict:
    hashes = {name: name.encode().hex().ljust(64, "0")[:64] for name in ("lock", "decl", "bind", "nar", "closure", "req", "iso", "payload", "provision", "identity", "model", "serial")}
    return {
        "schemaVersion": 1,
        "transactionId": "a" * 48,
        "sourceGitCommit": "b" * 40,
        "flakeLockSha256": hashes["lock"],
        "hostId": "fixture-host",
        "target": "nixosConfigurations.remembrance",
        "declarationDigest": hashes["decl"],
        "installerBootId": BOOT_ID,
        "installerDeviceBindingSha256": hashes["bind"],
        "installerSystemPath": "/nix/store/fixture-installer",
        "installerTopLevelNarHash": hashes["nar"],
        "installerClosureDigest": hashes["closure"],
        "manifestRequestSha256": hashes["req"],
        "recoverySystemPath": "/nix/store/fixture-recovery",
        "recoveryTopLevelNarHash": hashes["nar"].replace("0", "1"),
        "recoveryClosureDigest": hashes["closure"].replace("0", "1"),
        "candidateSystemPath": "/nix/store/fixture-candidate",
        "candidateTopLevelNarHash": hashes["nar"].replace("0", "2"),
        "candidateClosureDigest": hashes["closure"].replace("0", "2"),
        "isoArtifactSizeBytes": 4096,
        "isoSha256": hashes["iso"],
        "payloadManifestSha256": hashes["payload"],
        "releaseSignerFingerprint": "SHA256:fixture",
        "provisioningPayloadSha256": hashes["provision"],
        "diskById": "fixture-disk",
        "diskIdentitySha256": hashes["identity"],
        "sizeBytes": 1000204886016,
        "logicalSectorBytes": 512,
        "modelSha256": hashes["model"],
        "serialSha256": hashes["serial"],
        "endpoint": {"address": "192.0.2.10", "port": 22},
        "transportCapability": "network.ethernet",
        "installerHostPublicKey": "ssh-ed25519 AAAAfixture",
        "installerHostKeyFingerprint": "SHA256:host",
        "finalHostKeyFingerprint": "SHA256:final",
        "installKeyPublicKey": "ssh-ed25519 AAAAinstall",
        "installKeyFingerprint": "SHA256:install",
        "permanentLoginKeyFingerprint": "SHA256:login",
        "installAuthorizerPrincipal": "fixture-installer",
        "issuedAt": "2026-01-01T00:00:00Z",
        "expiresAt": "2026-01-01T00:15:00Z",
        "nonce": "c" * 48,
        "subactions": ["erase-install", "provision", "reboot-recovery"],
    }


def fixture_case(selector: str, root: Path) -> int:
    topology = write_topology(root)
    facts = resolve_fixture(topology, "/dev/disk/by-id/fixture-disk")
    if selector == "F01-real-tool-private-node":
        sandbox = parse_canonical(write_sandbox(root).read_bytes())
        validate_tool_sandbox(sandbox)
        private = root / "private" / "disk" / "by-id"
        private.mkdir(mode=0o700, parents=True)
        broker = ToolBroker(sandbox, private.parent.parent, "sfdisk")
        broker.executable_transition()
        broker.device(0, "/run/nix-config-device/fixture/disk/by-id/fixture-disk", 512, 524418, "cwd", "whole", "write")
        result = broker.exit()
        assert result["state"] == "exited" and result["writes"] == 1
        return 0
    if selector == "F02-canonical-disk-identity":
        assert len(facts.identity_digest()) == 64
        assert len(facts.binding_digest(BOOT_ID)) == 64
        projection = facts.identity_projection()
        assert canonical(projection) == canonical(parse_canonical(canonical(projection)))
        return 0
    if selector == "F03-by-id-relative-whole-device":
        assert facts.disk_by_id == "/dev/disk/by-id/fixture-disk" and not facts.partition
        return 0
    if selector == "F04-journal-canonical-chain":
        journal = make_journal("direct", "fixture-host")
        for state in ("erase-approved", "partition-writer-in-flight", "partitioned", "format-writer-in-flight:part1", "formatted:part1", "format-writer-in-flight:part2", "formatted:part2", "provisioned", "identity-staged", "identity-ready", "verification-snapshot-ready", "recovery-reboot-approved", "recovery-esp-budget-verified", "recovery-reboot-consumed", "recovery-boot-entry-in-flight", "recovery-boot-pending", "recovery-boot-verified", "rollback-transaction-prepared", "boot-verified"):
            journal = journal.append(state, {"state": state})
        journal.verify()
        assert journal.state == "boot-verified"
        return 0
    if selector == "F05-durable-snapshot-promotion":
        staging = root / "staging"
        persistent = root / "persistent" / "journal.json"
        journal = make_journal("direct", "fixture-host")
        save_journal(staging / "journal.json", journal)
        promoted = promote_staging(staging, persistent)
        assert promoted.terminal_digest == journal.terminal_digest and persistent.is_file()
        assert not (staging / "journal.json").exists()
        return 0
    if selector == "F06-identity-staging":
        frames = [b"identity-frame-1", b"identity-frame-2"]
        ready = stage_identity(root / "target", "a" * 48, "fixture-host", frames)
        expected = __import__("hashlib").sha256(b"".join(frames)).hexdigest()
        activated = activate_identity(root / "target", "a" * 48, "fixture-host", expected)
        assert ready.is_file() and activated.is_file()
        return 0
    return 2


def negative_case(selector: str, root: Path) -> int:
    topology = write_topology(root)
    if selector == "N01-by-id-outside-dev":
        return expect_rejected(lambda: (write_topology(root, link_target="/tmp/other"), resolve_fixture(topology, "/dev/disk/by-id/fixture-disk")))
    if selector == "N02-by-id-absolute-link":
        return expect_rejected(lambda: (write_topology(root, link_target="/dev/../tmp/other"), resolve_fixture(topology, "/dev/disk/by-id/fixture-disk")))
    if selector == "N03-by-id-magic-link":
        return expect_rejected(lambda: (write_topology(root, link_target="../proc/self/fd/1"), resolve_fixture(topology, "/dev/disk/by-id/fixture-disk")))
    journal = make_journal("direct", "fixture-host")
    if selector == "N04-journal-prefix-mutation":
        journal = journal.append("erase-approved", {"approvalDigest": "f" * 64})
        journal.value["entries"][0]["data"]["mediaVerificationDigest"] = "0" * 64
        return expect_rejected(journal.verify)
    if selector == "N05-journal-state-reorder":
        journal = journal.append("erase-approved", {})
        journal.value["entries"].reverse()
        return expect_rejected(journal.verify)
    if selector == "N06-journal-inflight-resume":
        journal = journal.append("erase-approved", {}).append("partition-writer-in-flight", {})
        return expect_rejected(lambda: reject_resume_from_inflight(journal))
    if selector == "N07-journal-promotion-crash":
        staging = root / "staging"
        save_journal(staging / "journal.json", journal)
        persistent = root / "persistent/journal.json"
        persistent.parent.mkdir(parents=True)
        persistent.write_bytes(b"partial")
        return expect_rejected(lambda: promote_staging(staging, persistent))
    if selector == "N08-journal-divergent-collision":
        staging = root / "staging"
        persistent = root / "persistent/journal.json"
        save_journal(staging / "journal.json", journal)
        save_journal(persistent, journal.append("erase-approved", {}))
        return expect_rejected(lambda: promote_staging(staging, persistent))
    if selector == "N10-manifest-fields":
        value = make_manifest()
        value["unexpected"] = True
        return expect_rejected(lambda: validate_manifest(value))
    if selector == "N11-signature-contract":
        value = make_manifest()
        value["releaseSignerFingerprint"] = "bad"
        return expect_rejected(lambda: validate_manifest(value))
    if selector == "N12-runtime-key-correspondence":
        value = make_manifest()
        value["installerHostPublicKey"] = "not-key"
        return expect_rejected(lambda: validate_manifest(value))
    if selector == "N13-runtime-system-closure":
        value = make_manifest()
        value["candidateSystemPath"] = "/tmp/candidate"
        return expect_rejected(lambda: validate_manifest(value))
    if selector == "N14-endpoint-canonicalization":
        value = make_manifest()
        value["endpoint"] = {"address": "192.0.2.010", "port": 22}
        return expect_rejected(lambda: validate_manifest(value))
    if selector == "N15-manifest-request-binding":
        value = make_manifest()
        value["manifestRequestSha256"] = "0" * 64
        return expect_rejected(lambda: validate_manifest(value))
    if selector == "N16-transport-live-route":
        value = make_manifest()
        value["transportCapability"] = "network.wifi"
        return expect_rejected(lambda: validate_manifest(value))
    if selector == "N17-clock-window":
        value = make_manifest()
        value["issuedAt"] = "bad"
        return expect_rejected(lambda: validate_manifest(value))
    if selector == "N18-transaction-deadline":
        value = make_manifest()
        value["expiresAt"] = "2026-01-01T00:00:00Z"
        return expect_rejected(lambda: validate_manifest(value))
    if selector == "N22-identity-medium-rebind":
        original = resolve_fixture(topology, "/dev/disk/by-id/fixture-disk")
        changed = write_topology(root, parent="/sys/devices/pci0000:00/nvme1")
        current = resolve_fixture(changed, "/dev/disk/by-id/fixture-disk")
        return expect_rejected(lambda: (_ for _ in ()).throw(ContractError("device-rebound")) if original != current else None)
    if selector == "N23-by-id-rebind":
        changed = write_topology(root, link_target="../../sda")
        return expect_rejected(lambda: resolve_fixture(changed, "/dev/disk/by-id/fixture-disk"))
    if selector == "N24-partition-parent-swap":
        changed = write_topology(root, partition=True)
        return expect_rejected(lambda: resolve_fixture(changed, "/dev/disk/by-id/fixture-disk"))
    if selector == "N25-mounted-swap-holder":
        changed = write_topology(root, mounted=True, swap=True, holders=["dm-0"])
        return expect_rejected(lambda: resolve_fixture(changed, "/dev/disk/by-id/fixture-disk"))
    return 2


def main(mode: str, selector: str) -> int:
    with tempfile.TemporaryDirectory(prefix="task7-") as temporary:
        root = Path(temporary)
        return fixture_case(selector, root) if mode == "fixture" else negative_case(selector, root)


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in ("fixture", "negative"):
        raise SystemExit(2)
    raise SystemExit(main(sys.argv[1], sys.argv[2]))
