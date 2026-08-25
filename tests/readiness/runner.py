#!/usr/bin/env python3
"""Small fixture-only runner for the integrated G012 readiness slices."""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, NoReturn

TASKS = frozenset({7, 15, 17, 22, 23})


def die(message: str) -> NoReturn:
    print(f"readiness runner: {message}", file=sys.stderr)
    raise SystemExit(2)


def canonical(value: object) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def load_manifest(path: Path, task: int) -> list[dict[str, Any]]:
    try:
        raw = path.read_bytes()
        value = json.loads(raw)
    except (OSError, json.JSONDecodeError) as error:
        die(f"invalid manifest: {error}")
    if raw != canonical(value):
        die("manifest is not canonical JSON")
    if not isinstance(value, dict) or set(value) != {"cases", "schemaVersion", "task"}:
        die("manifest shape")
    if value["schemaVersion"] != 1 or value["task"] != task or not isinstance(value["cases"], list):
        die("manifest task/version")
    cases = value["cases"]
    if cases != sorted(cases, key=lambda row: (row["mode"].encode(), row["caseId"].encode())):
        die("manifest cases are not ordered")
    seen: set[str] = set()
    for row in cases:
        if not isinstance(row, dict) or set(row) != {
            "caseId",
            "expectedExitClass",
            "mode",
            "timeoutSeconds",
        }:
            die("manifest case shape")
        if row["mode"] not in {"fixture", "negative"}:
            die("unsupported case mode")
        expected = "exit-0" if row["mode"] == "fixture" else "exit-nonzero"
        if row["expectedExitClass"] != expected:
            die("case expectation does not match mode")
        if not isinstance(row["timeoutSeconds"], int) or isinstance(row["timeoutSeconds"], bool) or not 1 <= row["timeoutSeconds"] <= 300:
            die("case timeout")
        if not isinstance(row["caseId"], str) or not row["caseId"] or row["caseId"] in seen:
            die("case id")
        seen.add(row["caseId"])
    return cases


def actual_exit(returncode: int | None) -> dict[str, Any]:
    if returncode is None:
        return {"kind": "timeout"}
    if returncode < 0:
        return {"kind": "signal", "signal": -returncode}
    return {"code": returncode, "kind": "exit"}


def matched(expected: str, returncode: int | None) -> bool:
    if expected == "exit-0":
        return returncode == 0
    if expected == "exit-nonzero":
        return returncode is not None and returncode > 0
    return False


def run_case(root: Path, adapter: Path, row: dict[str, Any]) -> dict[str, Any]:
    started = time.monotonic_ns()
    env = {
        **os.environ,
        "LC_ALL": "C",
        "NIXOS_REPO_ROOT": str(root),
        "PYTHONDONTWRITEBYTECODE": "1",
        "PYTHONPATH": str(root),
        "TZ": "UTC",
    }
    try:
        completed = subprocess.run(
            [str(adapter), row["mode"], row["caseId"]],
            cwd=root,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=row["timeoutSeconds"],
            check=False,
        )
        returncode: int | None = completed.returncode
        stdout = completed.stdout
        stderr = completed.stderr
    except subprocess.TimeoutExpired as error:
        returncode = None
        stdout = error.stdout or b""
        stderr = error.stderr or b""
    duration = (time.monotonic_ns() - started) // 1_000_000
    ok = matched(row["expectedExitClass"], returncode)
    if not ok:
        sys.stderr.buffer.write(stdout)
        sys.stderr.buffer.write(stderr)
    return {
        "actualExit": actual_exit(returncode),
        "caseId": row["caseId"],
        "durationMs": duration,
        "expectedExitClass": row["expectedExitClass"],
        "result": "matched" if ok else "mismatched",
    }


def validate_result(value: dict[str, Any]) -> None:
    assert set(value) == {
        "cases",
        "mode",
        "outcome",
        "protectedActions",
        "schemaVersion",
        "selector",
        "task",
    }
    assert value["schemaVersion"] == 1 and value["task"] in TASKS
    assert value["mode"] in {"fixture", "negative"}
    assert value["outcome"] in {"PASS", "INVALID"}
    assert isinstance(value["selector"], (str, type(None)))
    assert set(value["protectedActions"]) == {
        "diskWriters",
        "externalPublishes",
        "passwordChanges",
        "providerCalls",
        "reboots",
        "signingCalls",
    }
    assert all(count == 0 for count in value["protectedActions"].values())
    for row in value["cases"]:
        assert set(row) == {
            "actualExit",
            "caseId",
            "durationMs",
            "expectedExitClass",
            "result",
        }
        assert row["expectedExitClass"] in {"exit-0", "exit-nonzero"}
        assert row["result"] in {"matched", "mismatched"}
        assert isinstance(row["durationMs"], int) and row["durationMs"] >= 0
        actual = row["actualExit"]
        assert actual["kind"] in {"exit", "signal", "timeout"}
        assert set(actual) == {
            "kind",
            "code" if actual["kind"] == "exit" else "signal" if actual["kind"] == "signal" else "kind",
        }


def main(arguments: list[str]) -> int:
    if len(arguments) not in {3, 4}:
        die("usage: run-task.sh TASK fixture|negative [CASE_ID]")
    try:
        task = int(arguments[1])
    except ValueError:
        die("task must be numeric")
    if task not in TASKS:
        die("task is not integrated by this slice")
    mode = arguments[2]
    if mode not in {"fixture", "negative"}:
        die("mode must be fixture or negative")
    selector = arguments[3] if len(arguments) == 4 else None

    root = Path(__file__).resolve().parents[2]
    adapter = root / f"tests/readiness/adapters/task-{task}.sh"
    manifest = root / f"tests/readiness/cases/task-{task}.json"
    if not adapter.is_file() or not os.access(adapter, os.X_OK):
        die("adapter missing or not executable")
    selected = [row for row in load_manifest(manifest, task) if row["mode"] == mode]
    if selector is not None:
        selected = [row for row in selected if row["caseId"] == selector]
    if not selected:
        die("selector is not registered for this task and mode")

    results = [run_case(root, adapter, row) for row in selected]
    outcome = "PASS" if all(row["result"] == "matched" for row in results) else "INVALID"
    result = {
        "cases": results,
        "mode": mode,
        "outcome": outcome,
        "protectedActions": {
            "diskWriters": 0,
            "externalPublishes": 0,
            "passwordChanges": 0,
            "providerCalls": 0,
            "reboots": 0,
            "signingCalls": 0,
        },
        "schemaVersion": 1,
        "selector": selector,
        "task": task,
    }
    validate_result(result)
    sys.stdout.buffer.write(canonical(result))
    return 0 if outcome == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
