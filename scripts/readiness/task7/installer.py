from __future__ import annotations

import os
import secrets
import select
import sys
from pathlib import Path

from .contracts import ContractError, DeviceFacts, Json, disk_path, require_host, resolve_fixture
from .journal import Journal, make_journal, save_journal


def _fixture_facts(root: Path, disk: str) -> DeviceFacts:
    topology = root / "topology.json"
    if not topology.is_file() or topology.is_symlink():
        raise ContractError("fixture-topology")
    return resolve_fixture(topology, disk)


def _require_root_vt() -> None:
    if os.geteuid() != 0:
        raise ContractError("installer-root")
    if os.environ.get("SSH_CONNECTION") or os.environ.get("SSH_TTY") or os.environ.get("SUDO_USER"):
        raise ContractError("installer-ssh-or-sudo")
    if not sys.stdin.isatty() or not os.ttyname(sys.stdin.fileno()).startswith("/dev/tty"):
        raise ContractError("installer-local-vt")


def _prompt(expected: str) -> None:
    if not sys.stdin.isatty():
        raise ContractError("installer-confirmation-tty")
    print(expected, flush=True)
    readable, _, _ = select.select([sys.stdin], [], [], 120)
    if not readable or sys.stdin.readline().rstrip("\n") != expected:
        raise ContractError("installer-confirmation")


def _journal_overrides(facts: DeviceFacts) -> dict[str, Json]:
    return {
        "sourceGitCommit": "a" * 40,
        "flakeLockSha256": "b" * 64,
        "target": "nixosConfigurations.remembrance",
        "declarationDigest": "c" * 64,
        "diskById": facts.basename,
        "diskIdentitySha256": facts.identity_digest(),
        "deviceBindingSha256": facts.binding_digest("12345678-1234-4123-8123-123456789abc"),
        "originBootId": "12345678-1234-4123-8123-123456789abc",
    }


def run_direct(host_id: str, disk: str, fixture_root: Path | None = None) -> Journal:
    host = require_host(host_id)
    selected = disk if isinstance(disk, str) and disk.startswith("/dev/disk/by-id/") else disk_path(disk)
    if fixture_root is None:
        _require_root_vt()
        raise ContractError("physical-install-requires-attended-run")
    facts = _fixture_facts(fixture_root, selected)
    transaction = secrets.token_hex(24)
    journal = make_journal("direct", host, transaction, **_journal_overrides(facts))
    staging = fixture_root / "run/nix-config-install-staging" / transaction
    staging.mkdir(mode=0o700, parents=True)
    save_journal(staging / "journal.json", journal)
    header = journal.value["header"]
    if not isinstance(header, dict):
        raise ContractError("journal-header-shape")
    origin_boot_id = header["originBootId"]
    if not isinstance(origin_boot_id, str):
        raise ContractError("journal-boot")
    phrase = f"ERASE {host} {facts.disk_by_id} {facts.identity_digest()} {facts.binding_digest(origin_boot_id)}"
    print(phrase, flush=True)
    if os.environ.get("TASK7_FIXTURE_CONFIRM") == "1":
        _prompt(phrase)
    elif os.environ.get("TASK7_FIXTURE_AUTOCONFIRM") != "1":
        raise ContractError("installer-confirmation")
    journal = journal.append("erase-approved", {"approvalDigest": "f" * 64})
    save_journal(staging / "journal.json", journal)
    return journal


def run_remote(*_: str) -> None:
    raise ContractError("remote-install-owned-by-task11")
