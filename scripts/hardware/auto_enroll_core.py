# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
# Core of the ISO auto-enrollment: probe real hardware, sanitize through the
# collector, diff against the build-time base, re-validate, and write the
# candidate + RFC-6902 intake artifacts (idempotent overwrite).
from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path

from scripts.hardware.collector import collect_fixture
from scripts.hardware.intake import apply_intake, build_intake
from scripts.hardware.probe import probe_fixture
from scripts.support.canonical_json import JsonValue, encode, read_regular, require_canonical


def _load_canonical(path: Path) -> JsonValue:
    return require_canonical(read_regular(path))


def _now_utc() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def run_enrollment(
    *,
    host_id: str,
    base_path: Path,
    trust_path: Path,
    out_dir: Path,
    reviewer: str,
) -> tuple[Path, Path]:
    base = _load_canonical(base_path)
    if base["hostId"] != host_id:
        raise ValueError(f"base hostId {base['hostId']} does not match --host {host_id}")

    trust = _load_canonical(trust_path)
    if not isinstance(trust, dict) or not {"installAuthorizerPublicKey", "permanentLoginPublicKey", "finalHostPublicKey", "hostAgeRecipient", "recoveryAgeRecipient"}.issubset(trust):
        raise ValueError("trust fixture must carry the public/secret trust fields")

    disk_by_id = base.get("storage", {}).get("diskById")
    if not isinstance(disk_by_id, str) or not disk_by_id:
        raise ValueError("base declaration has no storage.diskById to enroll")

    fixture = probe_fixture(base, disk_by_id, trust)
    candidate = collect_fixture(fixture)
    intake = build_intake(base, candidate, reviewer, _now_utc())
    applied = apply_intake(base, intake)  # re-validates fail-closed

    out_dir.mkdir(parents=True, exist_ok=True)
    candidate_path = out_dir / f"{host_id}.json"
    intake_path = out_dir / f"{host_id}.intake.json"
    # Idempotent: overwrite any prior artifact for the host.
    candidate_path.write_bytes(encode(applied))
    intake_path.write_bytes(encode(intake))
    return candidate_path, intake_path
