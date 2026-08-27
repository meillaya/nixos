# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
# Core of the ISO auto-enrollment: probe real hardware, sanitize through the
# collector, diff against the build-time base, re-validate, and write the
# candidate + RFC-6902 intake artifacts (idempotent overwrite).
# Core of the ISO auto-enrollment: probe real hardware (auto-discovering the
# target disk), generate a fresh host SSH identity, sanitize through the
# collector, diff against the build-time base, re-validate, and write the
# candidate + RFC-6902 intake artifacts (idempotent overwrite). The host private
# key is written alongside so the operator can install/retain it.
from __future__ import annotations

import subprocess
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


def _generate_host_key(out_dir: Path, host_id: str) -> str:
    """Generate a fresh ed25519 host keypair; return the bare public key.

    The private key is written to <out_dir>/<host_id>.host-key (0600). The
    public key is returned as "ssh-ed25519 <base64>" (no comment) so the
    collector can derive the matching fingerprint.
    """
    priv = out_dir / f"{host_id}.host-key"
    pub = out_dir / f"{host_id}.host-key.pub"
    result = subprocess.run(
        ["ssh-keygen", "-t", "ed25519", "-N", "", "-C", f"{host_id}-host", "-f", str(priv)],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise ValueError("failed to generate host SSH key")
    public_line = pub.read_text().strip()
    return " ".join(public_line.split()[:2])


def run_enrollment(
    *,
    host_id: str,
    base_path: Path,
    trust_path: Path,
    out_dir: Path,
    reviewer: str,
    disk_by_id: str | None = None,
) -> tuple[Path, Path]:
    base = _load_canonical(base_path)
    if base["hostId"] != host_id:
        raise ValueError(f"base hostId {base['hostId']} does not match --host {host_id}")

    trust = _load_canonical(trust_path)
    if not isinstance(trust, dict) or not {"installAuthorizerPublicKey", "permanentLoginPublicKey", "finalHostPublicKey", "hostAgeRecipient", "recoveryAgeRecipient"}.issubset(trust):
        raise ValueError("trust fixture must carry the public/secret trust fields")

    out_dir.mkdir(parents=True, exist_ok=True)

    # Fresh host identity per install: the machine's own key rotates. The
    # install-authorizer and permanent-login keys stay as committed operator
    # keys; only the host (finalHost) key is regenerated.
    host_public = _generate_host_key(out_dir, host_id)
    trust["finalHostPublicKey"] = host_public

    # Auto-discover the target disk (the machine's real disk, not the committed
    # one) so a different physical machine can take over the host slot. An
    # explicit --disk pins it for ambiguous multi-disk machines.
    fixture = probe_fixture(base, trust, disk_by_id=disk_by_id)
    candidate = collect_fixture(fixture)
    intake = build_intake(base, candidate, reviewer, _now_utc())
    applied = apply_intake(base, intake)  # re-validates fail-closed

    candidate_path = out_dir / f"{host_id}.json"
    intake_path = out_dir / f"{host_id}.intake.json"
    # Idempotent: overwrite any prior artifact for the host.
    candidate_path.write_bytes(encode(applied))
    intake_path.write_bytes(encode(intake))
    return candidate_path, intake_path
