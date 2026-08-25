#!/usr/bin/env python3
"""Small, host-independent model of the Darwin activation contract.

The real activation journal is deliberately root-only and only runs on an
Apple Silicon host.  This model exercises the byte-level invariants and the
attended state machine without invoking darwin-rebuild, TCC, LaunchServices,
or Homebrew.  It is used by the readiness adapter as a portable fixture only.
External evidence gates are absent; native status is NOT VERIFIED.
"""
from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import json
import re
from typing import Any

SCHEMA_VERSION = 1
STATES = (
    "prepared",
    "candidate-switched",
    "relogged",
    "checks-passed",
    "drill-authorized",
    "previous-active",
    "restoration-authorized",
    "restored",
)
NEXT = {
    "prepared": "candidate-switched",
    "candidate-switched": "relogged",
    "relogged": "checks-passed",
    "checks-passed": "drill-authorized",
    "drill-authorized": "previous-active",
    "previous-active": "restoration-authorized",
    "restoration-authorized": "restored",
}
CHECKS = (
    "switch",
    "relogin",
    "rollback",
    "network",
    "aqua-tcc",
    "coretext-kitty",
    "spotlight",
    "launchservices",
    "emacs-offline",
)
JOURNAL_ROOT = "/var/db/nix-config/activation-transactions"
FIXTURE_MANIFEST_SHA256 = "6b21e125b25a2b0f7d4c34981f90f73e8a81c30394cc8044d06c24155663a83e"
HEX64 = re.compile(r"^[0-9a-f]{64}$")
COMMIT = re.compile(r"^[0-9a-f]{40}$")
ID192 = re.compile(r"^[0-9a-f]{48}$")
NAR = re.compile(r"^sha256-[A-Za-z0-9+/]{43}=$")
STORE = re.compile(r"^/nix/store/[0-9a-z]{32}-[A-Za-z0-9+._?=-]+(?:/[A-Za-z0-9+._?=/-]+)?$")
HASH_TOOL = re.compile(
    r"^/nix/store/[0-9a-z]{32}-coreutils-[A-Za-z0-9+._?=-]+/bin/sha256sum$"
)
UUID4 = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
INSTANT = re.compile(r"^20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")
PREVIOUS_GENERATION_KEYS = {
    "schemaVersion",
    "generation",
    "kind",
    "previousGithubRecordId",
    "foundationCommit",
    "githubStatus",
}


def canonical(value: Any) -> bytes:
    """Canonical JSON bytes used by every fixture file and digest."""
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def digest(value: Any) -> str:
    return hashlib.sha256(canonical(value)).hexdigest()


def _instant(value: str) -> datetime:
    if not isinstance(value, str) or not INSTANT.fullmatch(value):
        raise ValueError("timestamps must be UTC seconds with a Z suffix")
    return datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)


def _check_digest(value: Any, label: str) -> None:
    if not isinstance(value, str) or not HEX64.fullmatch(value):
        raise ValueError(f"{label} must be lowercase SHA-256 hex")


def _check_commit(value: Any, label: str) -> None:
    if not isinstance(value, str) or not COMMIT.fullmatch(value):
        raise ValueError(f"{label} must be a full lowercase Git commit")


def _check_store(value: Any, label: str) -> None:
    if not isinstance(value, str) or not STORE.fullmatch(value):
        raise ValueError(f"{label} must be a safe Nix store path")


def _check_nar(value: Any, label: str) -> None:
    if not isinstance(value, str) or not NAR.fullmatch(value):
        raise ValueError(f"{label} must be a SRI SHA-256 NAR hash")


def validate_previous_generation(value: Any) -> None:
    if not isinstance(value, dict) or set(value) != PREVIOUS_GENERATION_KEYS:
        raise ValueError("previous generation marker is not closed")
    if value["schemaVersion"] != 1 or value["generation"] != 1 or value["kind"] != "foundation":
        raise ValueError("foundation generation marker")
    if not UUID4.fullmatch(value["previousGithubRecordId"]):
        raise ValueError("previous GitHub record id")
    _check_commit(value["foundationCommit"], "foundationCommit")
    if value["githubStatus"] != "passed":
        raise ValueError("previous GitHub status")


def _check_scan(scan: Any, label: str) -> None:
    required = {
        "inputManifestSha256",
        "fixtureManifestSha256",
        "approvedPublicFixtureBaseMatchCount",
        "approvedPublicFixtureRepresentationMatchCount",
        "matchCount",
        "complete",
    }
    if not isinstance(scan, dict) or set(scan) != required:
        raise ValueError(f"{label} closure scan shape")
    _check_digest(scan["inputManifestSha256"], f"{label}.inputManifestSha256")
    if scan["fixtureManifestSha256"] != FIXTURE_MANIFEST_SHA256:
        raise ValueError(f"{label}.fixtureManifestSha256")
    if any(scan[k] != 0 for k in ("approvedPublicFixtureBaseMatchCount", "approvedPublicFixtureRepresentationMatchCount", "matchCount")):
        raise ValueError(f"{label} unexpected closure match")
    if scan["complete"] is not True:
        raise ValueError(f"{label} scan incomplete")


def validate_generation(generation: Any, candidate: dict[str, Any], previous: dict[str, Any]) -> None:
    """Validate the generation marker and its reviewed ancestor relation."""
    if not isinstance(generation, dict):
        raise ValueError("generation marker must be an object")
    if set(generation) != {"schemaVersion", "generation", "kind", "previousSourceGitCommit"}:
        raise ValueError("generation marker is not closed")
    if generation["schemaVersion"] != 1 or generation["generation"] != 2 or generation["kind"] != "candidate":
        raise ValueError("candidate generation marker")
    _check_commit(generation["previousSourceGitCommit"], "previousSourceGitCommit")
    if generation["previousSourceGitCommit"] != previous["sourceGitCommit"]:
        raise ValueError("generation previous commit does not name previous closure")
    if generation["previousSourceGitCommit"] == candidate["sourceGitCommit"]:
        raise ValueError("candidate self-references")
    if previous.get("foundationCommit") != generation["previousSourceGitCommit"]:
        raise ValueError("previous generation is not the reviewed foundation")
    if previous.get("githubStatus") != "passed":
        raise ValueError("previous GitHub review is not passed")


def validate_journal(value: Any, expected_state: str | None = None) -> None:
    """Fail closed on the complete portable journal contract."""
    required = {
        "schemaVersion",
        "activationId",
        "state",
        "candidate",
        "previous",
        "platformExpectationsDigest",
        "loginId",
        "activationOperatorId",
        "observerId",
        "hashToolPath",
        "hashToolNarHash",
        "checks",
        "approvals",
        "transitions",
        "preparedAt",
        "updatedAt",
    }
    if not isinstance(value, dict) or set(value) != required:
        raise ValueError("journal shape is not closed")
    if value["schemaVersion"] != SCHEMA_VERSION or value["state"] not in STATES:
        raise ValueError("journal schema/state")
    if expected_state is not None and value["state"] != expected_state:
        raise ValueError("unexpected journal state")
    if not ID192.fullmatch(value["activationId"]):
        raise ValueError("activationId must be a 192-bit lowercase id")

    for field in ("platformExpectationsDigest",):
        _check_digest(value[field], field)
    if not HASH_TOOL.fullmatch(value["hashToolPath"]):
        raise ValueError("hash tool must be configured coreutils sha256sum")
    if "/usr/bin/" in value["hashToolPath"] or "homebrew" in value["hashToolPath"].lower():
        raise ValueError("ambient hash tool")
    _check_nar(value["hashToolNarHash"], "hashToolNarHash")

    ids = [value[k] for k in ("loginId", "activationOperatorId", "observerId")]
    if any(not ID192.fullmatch(x) for x in ids) or len(set(ids)) != 3:
        raise ValueError("login/activation identities must be distinct 192-bit ids")
    for field in ("preparedAt", "updatedAt"):
        _instant(value[field])
    if _instant(value["updatedAt"]) < _instant(value["preparedAt"]):
        raise ValueError("updatedAt precedes preparedAt")

    candidate = value["candidate"]
    previous = value["previous"]
    child_keys = {
        "sourceGitCommit",
        "flakeLockSha256",
        "declarationDigest",
        "systemPath",
        "topLevelNarHash",
        "closureDigest",
        "closureScan",
        "generation",
    }
    for label, child in (("candidate", candidate), ("previous", previous)):
        if not isinstance(child, dict) or set(child) != child_keys:
            raise ValueError(f"{label} generation shape")
        _check_commit(child["sourceGitCommit"], f"{label}.sourceGitCommit")
        _check_digest(child["flakeLockSha256"], f"{label}.flakeLockSha256")
        _check_digest(child["declarationDigest"], f"{label}.declarationDigest")
        _check_store(child["systemPath"], f"{label}.systemPath")
        _check_nar(child["topLevelNarHash"], f"{label}.topLevelNarHash")
        _check_digest(child["closureDigest"], f"{label}.closureDigest")
        _check_scan(child["closureScan"], f"{label}.closureScan")
        if not isinstance(child["generation"], dict):
            raise ValueError(f"{label}.generation shape")
    validate_previous_generation(previous["generation"])
    validate_generation(candidate["generation"], candidate, {**previous, **previous["generation"]})

    equal = ("flakeLockSha256", "declarationDigest")
    different = ("sourceGitCommit", "systemPath", "topLevelNarHash", "closureDigest")
    for key in equal:
        if candidate[key] != previous[key]:
            raise ValueError(f"candidate/previous {key} must match")
    for key in different:
        if candidate[key] == previous[key]:
            raise ValueError(f"candidate/previous {key} must differ")
    if candidate["closureScan"]["inputManifestSha256"] == previous["closureScan"]["inputManifestSha256"]:
        raise ValueError("candidate/previous closure scan inputs must differ")

    if not isinstance(value["checks"], list) or len(value["checks"]) != len(CHECKS):
        raise ValueError("exactly nine Darwin check envelopes required")
    check_ids = []
    for row, expected in zip(value["checks"], CHECKS):
        if not isinstance(row, dict) or set(row) != {"checkId", "envelopeDigest"} or row["checkId"] != expected:
            raise ValueError("check envelope selector order")
        _check_digest(row["envelopeDigest"], f"check {expected}")
        check_ids.append(row["checkId"])
    if len(set(check_ids)) != len(CHECKS):
        raise ValueError("duplicate check envelope")

    approvals = value["approvals"]
    if not isinstance(approvals, dict) or set(approvals) != {"rollback", "restore"}:
        raise ValueError("approval shape")
    for name, approval in approvals.items():
        if approval is None:
            continue
        if not isinstance(approval, dict) or set(approval) != {"approvalId", "approvedBy", "expiresAt", "used"}:
            raise ValueError(f"{name} approval shape")
        if not ID192.fullmatch(approval["approvalId"]):
            raise ValueError(f"{name} approval id")
        if approval["approvedBy"] != value["loginId"]:
            raise ValueError(f"{name} approval is not active console user")
        _instant(approval["expiresAt"])
        if not isinstance(approval["used"], bool):
            raise ValueError(f"{name} approval use marker")

    transitions = value["transitions"]
    if not isinstance(transitions, list) or not transitions:
        raise ValueError("missing fsynced transition history")
    state = "prepared"
    for row in transitions:
        if not isinstance(row, dict) or set(row) != {"from", "to", "fsyncedAt"}:
            raise ValueError("transition row shape")
        if row["from"] != state or NEXT.get(state) != row["to"]:
            raise ValueError("invalid/skipped journal transition")
        _instant(row["fsyncedAt"])
        state = row["to"]
    if state != value["state"]:
        raise ValueError("transition history does not reach current state")
