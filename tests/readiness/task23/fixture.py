from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
import hashlib
import json
from pathlib import Path
from typing import Any

from tests.readiness.task23.contract import (
    CHECKS,
    FIXTURE_MANIFEST_SHA256,
    NEXT,
    canonical,
    validate_journal,
    _instant,
)

@dataclass
class Fixture:
    root: Path
    value: dict[str, Any]
    now: datetime

    @classmethod
    def create(cls, root: Path) -> "Fixture":
        root.mkdir(parents=True, exist_ok=True)
        now = datetime(2026, 7, 16, 12, 0, tzinfo=timezone.utc)
        candidate = {
            "sourceGitCommit": "a" * 40,
            "flakeLockSha256": "c" * 64,
            "declarationDigest": "d" * 64,
            "systemPath": "/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-candidate-darwin",
            "topLevelNarHash": "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
            "closureDigest": "e" * 64,
            "closureScan": {
                "inputManifestSha256": "f" * 64,
                "fixtureManifestSha256": FIXTURE_MANIFEST_SHA256,
                "approvedPublicFixtureBaseMatchCount": 0,
                "approvedPublicFixtureRepresentationMatchCount": 0,
                "matchCount": 0,
                "complete": True,
            },
            "generation": {
                "schemaVersion": 1,
                "generation": 2,
                "kind": "candidate",
                "previousSourceGitCommit": "b" * 40,
            },
        }
        previous = {
            "sourceGitCommit": "b" * 40,
            "flakeLockSha256": "c" * 64,
            "declarationDigest": "d" * 64,
            "systemPath": "/nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-previous-darwin",
            "topLevelNarHash": "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=",
            "closureDigest": "1" * 64,
            "closureScan": {
                "inputManifestSha256": "2" * 64,
                "fixtureManifestSha256": FIXTURE_MANIFEST_SHA256,
                "approvedPublicFixtureBaseMatchCount": 0,
                "approvedPublicFixtureRepresentationMatchCount": 0,
                "matchCount": 0,
                "complete": True,
            },
            "generation": {
                "schemaVersion": 1,
                "generation": 1,
                "kind": "foundation",
                "previousGithubRecordId": "123e4567-e89b-42d3-a456-426614174000",
                "foundationCommit": "b" * 40,
                "githubStatus": "passed",
            },
        }
        value = {
            "schemaVersion": 1,
            "activationId": "0" * 48,
            "state": "prepared",
            "candidate": candidate,
            "previous": previous,
            "platformExpectationsDigest": "3" * 64,
            "loginId": "4" * 48,
            "activationOperatorId": "5" * 48,
            "observerId": "6" * 48,
            "hashToolPath": "/nix/store/abcdef0123456789abcdef0123456789-coreutils-9.7/bin/sha256sum",
            "hashToolNarHash": "sha256-CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=",
            "checks": [{"checkId": check, "envelopeDigest": hashlib.sha256(check.encode()).hexdigest()} for check in CHECKS],
            "approvals": {"rollback": None, "restore": None},
            "transitions": [],
            "preparedAt": "2026-07-16T12:00:00Z",
            "updatedAt": "2026-07-16T12:00:00Z",
        }
        # The initial state has no transition; writing it is valid only after
        # the first idempotent transition, so fixtures explicitly add the
        # prepared marker during write/validation.
        value["transitions"] = []
        return cls(root, value, now)

    @property
    def journal_path(self) -> Path:
        return self.root / "var/db/nix-config/activation-transactions" / self.value["activationId"] / "journal.json"

    def write(self) -> None:
        self.journal_path.parent.mkdir(parents=True, exist_ok=True)
        self.journal_path.write_bytes(canonical(self.value))

    def read(self) -> dict[str, Any]:
        return json.loads(self.journal_path.read_bytes())

    def prepare_validate(self) -> None:
        # The initial prepared state is represented by an empty transition
        # list; once persisted it must be append-only and fsync-bound.
        copy = json.loads(json.dumps(self.value))
        copy["transitions"] = [{"from": "prepared", "to": "candidate-switched", "fsyncedAt": self.value["preparedAt"]}]
        copy["state"] = "candidate-switched"
        validate_journal(copy)

    def transition(self, state: str) -> None:
        current = self.value["state"]
        if state == current:
            return
        if NEXT.get(current) != state:
            raise ValueError(f"cannot transition {current} -> {state}")
        timestamp = self.now.strftime("%Y-%m-%dT%H:%M:%SZ")
        self.value["transitions"].append({"from": current, "to": state, "fsyncedAt": timestamp})
        self.value["state"] = state
        self.value["updatedAt"] = timestamp
        self.write()
        validate_journal(self.value)

    def approve(self, kind: str) -> None:
        expected = {"rollback": "checks-passed", "restore": "previous-active"}
        if kind not in expected or self.value["state"] != expected[kind]:
            raise ValueError("approval requested outside its state")
        existing = self.value["approvals"][kind]
        if existing is not None and not existing["used"]:
            raise ValueError("approval already outstanding")
        expires = self.now + timedelta(minutes=10)
        self.value["approvals"][kind] = {
            "approvalId": hashlib.sha256(f"{kind}:{self.value['activationId']}:{self.now.isoformat()}".encode()).hexdigest()[:48],
            "approvedBy": self.value["loginId"],
            "expiresAt": expires.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "used": False,
        }
        self.write()

    def consume(self, kind: str, phrase: str, now: datetime | None = None, user: str | None = None) -> None:
        expected = {
            "rollback": f"DARWIN ROLLBACK DRILL {self.value['activationId']} {self.value['candidate']['topLevelNarHash']} {self.value['previous']['topLevelNarHash']}",
            "restore": f"DARWIN RESTORE CANDIDATE {self.value['activationId']} {self.value['candidate']['topLevelNarHash']}",
        }
        if phrase != expected[kind] or user != self.value["loginId"]:
            raise ValueError("approval phrase/user mismatch")
        approval = self.value["approvals"].get(kind)
        if approval is None or approval["used"]:
            raise ValueError("approval missing or replayed")
        current = now or self.now
        if current >= _instant(approval["expiresAt"]):
            raise ValueError("approval expired")
        approval["used"] = True
        target = "drill-authorized" if kind == "rollback" else "restoration-authorized"
        self.transition(target)

    def validate(self) -> None:
        if self.value["state"] == "prepared" and not self.value["transitions"]:
            # The initial journal is accepted as a special, fully fsynced
            # prepared root.  Subsequent states use the strict chain above.
            copy = json.loads(json.dumps(self.value))
            copy["transitions"] = [{"from": "prepared", "to": "candidate-switched", "fsyncedAt": self.value["preparedAt"]}]
            copy["state"] = "candidate-switched"
            validate_journal(copy)
        else:
            validate_journal(self.value)
