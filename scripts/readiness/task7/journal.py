from __future__ import annotations

import hashlib
import os
import re
import secrets
from dataclasses import dataclass
from pathlib import Path

from .contracts import (
    IN_FLIGHT,
    STATES,
    ContractError,
    Json,
    JsonObject,
    BOOT_ID,
    canonical,
    digest,
    exact_keys,
    parse_canonical,
    require_host,
    require_sha,
    require_disk_basename,
    require_transaction,
)


def new_transaction_id() -> str:
    return secrets.token_hex(24)


def transaction_id(value: object) -> str:
    return require_transaction(value)


def entry_digest(index: int, state: str, data: Json, previous: str | None) -> str:
    if not isinstance(state, str) or state not in STATES or not isinstance(data, dict):
        raise ContractError("journal-state")
    return digest(
        {
            "data": data,
            "index": index,
            "previousDigest": previous,
            "state": state,
        }
    )


@dataclass(frozen=True, slots=True)
class Journal:
    value: JsonObject

    @property
    def transaction_id(self) -> str:
        header = self.value["header"]
        if not isinstance(header, dict):
            raise ContractError("journal-header-shape")
        return require_transaction(header["transactionId"])

    @property
    def state(self) -> str:
        entries = self.value["entries"]
        if not isinstance(entries, list) or not entries:
            raise ContractError("journal-entries")
        entry = entries[-1]
        if not isinstance(entry, dict):
            raise ContractError("journal-entry-shape")
        state = entry.get("state")
        if not isinstance(state, str):
            raise ContractError("journal-entry-shape")
        return state

    @property
    def terminal_digest(self) -> str:
        return hashlib.sha256(canonical(self.value)).hexdigest()

    def verify(self) -> None:
        expected_top = {"header", "entries", "schemaVersion"}
        if set(self.value) != expected_top or self.value["schemaVersion"] != 1:
            raise ContractError("journal-shape")
        header = exact_keys(
            self.value["header"],
            {
                "mode",
                "sourceGitCommit",
                "flakeLockSha256",
                "hostId",
                "target",
                "declarationDigest",
                "diskById",
                "diskIdentitySha256",
                "deviceBindingSha256",
                "originBootId",
                "transactionId",
            },
            "journal-header",
        )
        require_transaction(header["transactionId"])
        require_host(header["hostId"])
        if header["mode"] not in ("direct", "remote"):
            raise ContractError("journal-mode")
        if not isinstance(header["sourceGitCommit"], str) or re.fullmatch(r"[0-9a-f]{40}", header["sourceGitCommit"]) is None:
            raise ContractError("journal-header-commit")
        for field in (
            "flakeLockSha256",
            "declarationDigest",
            "diskIdentitySha256",
            "deviceBindingSha256",
        ):
            field_digest = header[field]
            if not isinstance(field_digest, str) or re.fullmatch(r"[0-9a-f]{64}", field_digest) is None:
                raise ContractError("journal-header-digest")
        if not isinstance(header["target"], str) or not header["target"].startswith("nixosConfigurations."):
            raise ContractError("journal-target")
        require_disk_basename(header["diskById"])
        if not isinstance(header["originBootId"], str) or BOOT_ID.fullmatch(header["originBootId"]) is None:
            raise ContractError("journal-boot")
        entries = self.value["entries"]
        if not isinstance(entries, list) or not entries:
            raise ContractError("journal-entries")
        previous: str | None = None
        states: list[str] = []
        for index, item in enumerate(entries):
            entry = exact_keys(
                item,
                {
                    "data",
                    "entryDigest",
                    "index",
                    "previousDigest",
                    "state",
                },
                "journal-entry",
            )
            if entry["index"] != index or entry["previousDigest"] != previous:
                raise ContractError("journal-chain")
            data = entry["data"]
            if not isinstance(data, dict):
                raise ContractError("journal-entry-data")
            entry_hash = entry["entryDigest"]
            if not isinstance(entry_hash, str) or re.fullmatch(r"[0-9a-f]{64}", entry_hash) is None:
                raise ContractError("journal-entry-digest")
            state = entry["state"]
            if not isinstance(state, str):
                raise ContractError("journal-state")
            if entry_hash != entry_digest(index, state, data, previous):
                raise ContractError("journal-entry-digest")
            previous = entry_hash
            states.append(state)
        if states[0] != "prepared" or states != list(STATES[: len(states)]):
            raise ContractError("journal-state-order")

    def append(self, state: str, data: Json | None = None) -> "Journal":
        self.verify()
        if state not in STATES:
            raise ContractError("journal-state")
        if state in IN_FLIGHT and self.state in IN_FLIGHT:
            raise ContractError("journal-inflight")
        payload = {} if data is None else data
        if not isinstance(payload, dict):
            raise ContractError("journal-data")
        entries = self.value["entries"]
        if not isinstance(entries, list) or not entries:
            raise ContractError("journal-entries")
        expected = len(entries)
        if expected >= len(STATES) or STATES[expected] != state:
            raise ContractError("journal-transition")
        previous_entry = entries[-1]
        if not isinstance(previous_entry, dict):
            raise ContractError("journal-entry-shape")
        previous = require_sha(previous_entry["entryDigest"], "journal-entry")
        item: JsonObject = {
            "data": payload,
            "entryDigest": entry_digest(expected, state, payload, previous),
            "index": expected,
            "previousDigest": previous,
            "state": state,
        }
        value: JsonObject = {**self.value, "entries": [*entries, item]}
        result = Journal(value)
        result.verify()
        return result


def make_journal(
    mode: str,
    host_id: str,
    transaction: str | None = None,
    **header_overrides: Json,
) -> Journal:
    if mode not in ("direct", "remote"):
        raise ContractError("journal-mode")
    tx = new_transaction_id() if transaction is None else transaction_id(transaction)
    header: dict[str, Json] = {
        "mode": mode,
        "sourceGitCommit": "a" * 40,
        "flakeLockSha256": "b" * 64,
        "hostId": require_host(host_id),
        "target": "nixosConfigurations.remembrance",
        "declarationDigest": "c" * 64,
        "diskById": "fixture-disk",
        "diskIdentitySha256": "d" * 64,
        "deviceBindingSha256": "e" * 64,
        "originBootId": "12345678-1234-4123-8123-123456789abc",
        "transactionId": tx,
    }
    header.update(header_overrides)
    prepared_data: JsonObject = {"mediaVerificationDigest": "f" * 64}
    prepared_entry: JsonObject = {
        "data": prepared_data,
        "entryDigest": entry_digest(0, "prepared", prepared_data, None),
        "index": 0,
        "previousDigest": None,
        "state": "prepared",
    }
    value: JsonObject = {
        "entries": [prepared_entry],
        "header": header,
        "schemaVersion": 1,
    }
    journal = Journal(value)
    journal.verify()
    return journal


def atomic_write(path: Path, value: Json) -> None:
    if path.is_symlink() or any(part.is_symlink() for part in path.parent.parents if part != path.parent):
        raise ContractError("journal-symlink")
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    if path.parent.is_symlink():
        raise ContractError("journal-symlink")
    temporary = path.with_name(path.name + ".tmp")
    descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(canonical(value))
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    except BaseException:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass
        raise


def save_journal(path: Path, journal: Journal) -> None:
    journal.verify()
    atomic_write(path, journal.value)


def load_journal(path: Path) -> Journal:
    if path.is_symlink() or not path.is_file():
        raise ContractError("journal-path")
    value = parse_canonical(path.read_bytes())
    if not isinstance(value, dict):
        raise ContractError("journal-shape")
    journal = Journal(value)
    journal.verify()
    return journal


def promote_staging(staging: Path, persistent: Path) -> Journal:
    source = staging / "journal.json"
    if staging.is_symlink() or source.is_symlink():
        raise ContractError("journal-staging-path")
    journal = load_journal(source)
    if persistent.is_symlink():
        raise ContractError("journal-persistent-symlink")
    if persistent.exists():
        existing = load_journal(persistent)
        if existing.terminal_digest != journal.terminal_digest:
            raise ContractError("journal-divergent-collision")
        return existing
    persistent.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    persistent_directory = persistent.parent
    if persistent_directory.is_symlink():
        raise ContractError("journal-persistent-symlink")
    atomic_write(persistent, journal.value)
    source.unlink()
    return load_journal(persistent)


def reject_resume_from_inflight(journal: Journal) -> None:
    journal.verify()
    if journal.state in IN_FLIGHT:
        raise ContractError("destructive-recovery-required")
