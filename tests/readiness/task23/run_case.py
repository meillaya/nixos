#!/usr/bin/env python3
"""Portable Task 23 fixtures; external evidence gates are absent (NOT VERIFIED)."""
from __future__ import annotations

import sys
import tempfile
from datetime import timedelta
from pathlib import Path
from typing import Any, Callable

from tests.readiness.task23.model import Fixture, validate_journal


def progress(fixture: Fixture) -> None:
    fixture.transition("candidate-switched")
    fixture.transition("relogged")
    fixture.transition("checks-passed")


def fixture_case(selector: str, root: Path) -> int:
    fixture = Fixture.create(root)
    if selector == "F01-portable-journal-transitions":
        fixture.validate()
        progress(fixture)
        validate_journal(fixture.read(), "checks-passed")
        fixture.transition("checks-passed")
        assert [row["to"] for row in fixture.read()["transitions"]] == [
            "candidate-switched",
            "relogged",
            "checks-passed",
        ]
        return 0
    if selector == "F02-portable-restoration":
        progress(fixture)
        fixture.approve("rollback")
        rollback = (
            f"DARWIN ROLLBACK DRILL {fixture.value['activationId']} "
            f"{fixture.value['candidate']['topLevelNarHash']} "
            f"{fixture.value['previous']['topLevelNarHash']}"
        )
        fixture.consume("rollback", rollback, user=fixture.value["loginId"])
        fixture.transition("previous-active")
        fixture.approve("restore")
        restore = (
            f"DARWIN RESTORE CANDIDATE {fixture.value['activationId']} "
            f"{fixture.value['candidate']['topLevelNarHash']}"
        )
        fixture.consume("restore", restore, user=fixture.value["loginId"])
        fixture.transition("restored")
        validate_journal(fixture.read(), "restored")
        return 0
    return 2


def must_reject(value: dict[str, Any]) -> int:
    try:
        validate_journal(value)
    except (AssertionError, KeyError, TypeError, ValueError):
        return 1
    raise AssertionError("journal mutant accepted")


def independent_mutants(root: Path, mutations: tuple[Callable[[Fixture], None], ...]) -> int:
    for mutate in mutations:
        candidate = Fixture.create(root)
        progress(candidate)
        mutate(candidate)
        must_reject(candidate.value)
    return 1


def negative_case(selector: str, root: Path) -> int:
    fixture = Fixture.create(root)
    if selector == "N01-journal-schema-transition":
        progress(fixture)
        fixture.value["transitions"][-1]["to"] = "restored"
    elif selector == "N03-platform-expectations-shape":
        progress(fixture)
        fixture.value["platformExpectationsDigest"] = "z" * 64
    elif selector == "N04-lock-declaration-equality":
        progress(fixture)
        fixture.value["previous"]["flakeLockSha256"] = "9" * 64
    elif selector == "N05-source-path-nar-closure-distinctness":
        progress(fixture)
        fixture.value["previous"]["closureDigest"] = fixture.value["candidate"][
            "closureDigest"
        ]
    elif selector == "N06-generation-self-rev":
        progress(fixture)
        fixture.value["candidate"]["generation"]["previousSourceGitCommit"] = (
            fixture.value["candidate"]["sourceGitCommit"]
        )
    elif selector == "N07-closure-scan-graph":
        progress(fixture)
        fixture.value["candidate"]["closureScan"].pop("inputManifestSha256")
    elif selector == "N08-previous-github-review":
        progress(fixture)
        fixture.value["previous"]["generation"]["githubStatus"] = "pending"
    elif selector == "N09-mixed-previous-generation":
        return independent_mutants(
            root,
            (
                lambda value: value.value["previous"].update(sourceGitCommit="c" * 40),
                lambda value: value.value["previous"]["generation"].update(extra="stale"),
                lambda value: value.value["previous"]["generation"].update(schemaVersion=2),
                lambda value: value.value["previous"]["generation"].update(kind="candidate"),
            ),
        )
    elif selector == "N10-approval-expiry-replay":
        progress(fixture)
        fixture.approve("rollback")
        phrase = (
            f"DARWIN ROLLBACK DRILL {fixture.value['activationId']} "
            f"{fixture.value['candidate']['topLevelNarHash']} "
            f"{fixture.value['previous']['topLevelNarHash']}"
        )
        for user, now in (
            (None, fixture.now),
            (fixture.value["loginId"], fixture.now + timedelta(minutes=10)),
        ):
            candidate = Fixture.create(root)
            progress(candidate)
            candidate.approve("rollback")
            candidate_phrase = phrase.replace(
                fixture.value["activationId"], candidate.value["activationId"]
            )
            try:
                candidate.consume("rollback", candidate_phrase, now=now, user=user)
            except ValueError:
                continue
            raise AssertionError("approval omission/expiry accepted")
        fixture.consume("rollback", phrase, user=fixture.value["loginId"])
        try:
            fixture.consume("rollback", phrase, user=fixture.value["loginId"])
        except ValueError:
            return 1
        raise AssertionError("approval replay accepted")
    elif selector == "N11-crash-restoration":
        progress(fixture)
        fixture.approve("rollback")
        phrase = (
            f"DARWIN ROLLBACK DRILL {fixture.value['activationId']} "
            f"{fixture.value['candidate']['topLevelNarHash']} "
            f"{fixture.value['previous']['topLevelNarHash']}"
        )
        fixture.consume("rollback", phrase, user=fixture.value["loginId"])
        try:
            fixture.transition("restored")
        except ValueError:
            return 1
        raise AssertionError("crash path skipped explicit restoration")
    elif selector == "N12-portable-native-claim":
        claim = {
            "native": True,
            "platform": "linux",
            "externalGateStatus": "absent",
        }
        assert (
            claim["native"]
            and claim["platform"] != "aarch64-darwin"
            and claim["externalGateStatus"] == "absent"
        )
        return 1
    else:
        return 2
    return must_reject(fixture.value)


def main(mode: str, selector: str) -> int:
    with tempfile.TemporaryDirectory(prefix="task23-") as temporary:
        root = Path(temporary)
        if mode == "fixture":
            return fixture_case(selector, root)
        if mode == "negative":
            return negative_case(selector, root)
        return 2


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in {"fixture", "negative"}:
        raise SystemExit(2)
    raise SystemExit(main(sys.argv[1], sys.argv[2]))
