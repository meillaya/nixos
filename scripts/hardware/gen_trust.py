# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
# ─── How to run ───
# PYTHONPATH=<repo-root> python3 scripts/hardware/gen_trust.py [--host remembrance] [-o OUT]
#
# Emits the canonical operator trust.json consumed by the ISO auto-enrollment
# (scripts/hardware/auto_enroll_core.py requires the flat trust fields).
# Facts are sourced from the repo, never from the operator's live key material:
#   - installAuthorizerPublicKey / installAuthorizerPrincipal / ciphertexts:
#     copied verbatim from the committed config/hosts/intake/<host>.json
#   - permanentLoginPublicKey: derived from the sops-encrypted
#     secrets/remembrance-keys.yaml (<host>-permanent-login block) and
#     asserted equal to the committed record's publicTrust.permanentLoginPublicKey
#   - hostAgeRecipient / recoveryAgeRecipient: parsed from .sops.yaml
#   - finalHostPublicKey: "PLACEHOLDER" (auto_enroll_core overrides it with a
#     fresh per-install host key)
# The private key exists only in memory and in a 0600 temp file that is deleted
# immediately after the public key is derived. Any failure aborts before any
# output is written.
#
# A host that has not been enrolled yet has no committed record: its trust facts
# are the fleet-wide operator facts (authorizer key/principal, permanent-login
# key, age recipients, ciphertexts), so the committed record named by
# --fleet-record supplies them verbatim, without touching the sops store. The
# first enrollment of a new host therefore only needs the operator's own key
# material to already exist in the fleet record.
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

from scripts.support.canonical_json import (
    CanonicalJsonError,
    JsonValue,
    encode,
    read_regular,
    require_canonical,
)

_REPO = Path(__file__).resolve().parents[2]
_SOPS_FILE = _REPO / "secrets" / "remembrance-keys.yaml"
_SOPS_CONFIG = _REPO / ".sops.yaml"


def _sops_env() -> dict[str, str]:
    env = dict(os.environ)
    default_age = Path.home() / ".config" / "sops" / "age" / "keys.txt"
    if "SOPS_AGE_KEY_FILE" not in env and default_age.is_file():
        env["SOPS_AGE_KEY_FILE"] = str(default_age)
    return env


def _decrypt_sops(env: dict[str, str]) -> str:
    result = subprocess.run(
        ["sops", "--config", str(_SOPS_CONFIG), "-d", str(_SOPS_FILE)],
        capture_output=True,
        text=True,
        env=env,
    )
    if result.returncode != 0:
        raise ValueError("failed to decrypt secrets/remembrance-keys.yaml with sops")
    return result.stdout


def _extract_block(text: str, field: str) -> str:
    pattern = re.compile(rf"({re.escape(field)}: \|\n)((?:    .*\n)+)")
    matches = pattern.findall(text)
    if len(matches) != 1:
        raise ValueError(f"secret field {field!r} not found (exactly once) in sops store")
    return "".join(line[4:] + "\n" for line in matches[0][1].splitlines())


def _derived_public(private_text: str) -> str:
    handle, name = tempfile.mkstemp(prefix="gen-trust-", suffix=".key")
    tmp = Path(name)
    try:
        os.fchmod(handle, 0o600)
        with os.fdopen(handle, "w") as stream:
            stream.write(private_text)
        result = subprocess.run(
            ["ssh-keygen", "-y", "-f", str(tmp)],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            raise ValueError("cannot derive permanent-login public key from sops private key")
        return " ".join(result.stdout.strip().split()[:2])
    finally:
        tmp.unlink(missing_ok=True)


def _age_recipient(text: str, anchor: str) -> str:
    match = re.search(rf"&{anchor}\s+(age1\S+)", text)
    if match is None:
        raise ValueError(f"age recipient &{anchor} not found in .sops.yaml")
    return match.group(1)


def _trust_pair(path, label):
    value = require_canonical(read_regular(path))
    if not isinstance(value, dict) or "publicTrust" not in value or "secretTrust" not in value:
        raise ValueError(f"{label} {path} lacks publicTrust/secretTrust")
    public = value["publicTrust"]
    secret = value["secretTrust"]
    if not isinstance(public, dict) or not isinstance(secret, dict):
        raise ValueError(f"{label} publicTrust/secretTrust must be objects")
    return public, secret


def _same_operator_facts(record, fleet):
    public, secret = record
    fleet_public, fleet_secret = fleet
    return (
        public.get("installAuthorizerPrincipal") == fleet_public.get("installAuthorizerPrincipal")
        and public.get("installAuthorizerPublicKey") == fleet_public.get("installAuthorizerPublicKey")
        and public.get("permanentLoginPublicKey") == fleet_public.get("permanentLoginPublicKey")
        and secret.get("ciphertexts") == fleet_secret.get("ciphertexts")
    )


def build_trust(host_id: str, fleet_host: str = "remembrance") -> dict[str, JsonValue]:
    record_path = _REPO / "config" / "hosts" / "intake" / f"{host_id}.json"
    fleet_path = _REPO / "config" / "hosts" / "intake" / f"{fleet_host}.json"
    fleet = _trust_pair(fleet_path, "fleet record") if fleet_path.is_file() else None

    if record_path.is_file():
        record = _trust_pair(record_path, "committed intake record")
        try:
            sops_text = _decrypt_sops(_sops_env())
            private_key = _extract_block(sops_text, f"{host_id}-permanent-login")
        except ValueError:
            # No operator sops store on this machine. A host other than the
            # fleet anchor can still take the fleet-wide operator facts when
            # its committed record agrees with them, so a re-run on a live
            # environment without the backups keeps working; any divergence --
            # including asking for the fleet anchor host itself -- fails
            # closed with the strict message.
            if host_id == fleet_host or fleet is None or not _same_operator_facts(record, fleet):
                raise ValueError(
                    "failed to decrypt secrets/remembrance-keys.yaml with sops and no "
                    f"matching fleet operator facts for {host_id}; restore the operator secrets"
                )
            print(
                f"gen_trust: sops store unavailable; using fleet operator facts ({fleet_path})",
                file=sys.stderr,
            )
            public_trust, secret_trust = fleet
        else:
            public_trust, secret_trust = record
            derived = _derived_public(private_key)
            committed = public_trust.get("permanentLoginPublicKey")
            if not isinstance(committed, str) or derived != committed:
                raise ValueError(
                    "derived permanent-login public key does not match the committed record\n"
                    f"  derived : {derived}\n  committed: {committed}"
                )
    else:
        # First enrollment of a not-yet-enrolled host: the operator facts are
        # fleet-wide, so the fleet's committed record anchors them.
        if fleet is None:
            raise ValueError(
                f"no committed record for {host_id} and no fleet record at {fleet_path}"
            )
        public_trust, secret_trust = fleet

    return {
        "installAuthorizerPublicKey": public_trust["installAuthorizerPublicKey"],
        "installAuthorizerPrincipal": public_trust["installAuthorizerPrincipal"],
        "permanentLoginPublicKey": public_trust["permanentLoginPublicKey"],
        "finalHostPublicKey": "PLACEHOLDER",
        "hostAgeRecipient": _age_recipient(_SOPS_CONFIG.read_text(), "admin"),
        "recoveryAgeRecipient": _age_recipient(_SOPS_CONFIG.read_text(), "recovery"),
        "ciphertexts": secret_trust["ciphertexts"],
    }


def _parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(prog="gen_trust")
    parser.add_argument(
        "--host",
        default="remembrance",
        help="hostId whose committed intake record anchors the trust facts",
    )
    parser.add_argument(
        "--fleet-record",
        default="remembrance",
        help="hostId whose committed record supplies fleet operator facts when --host is not enrolled yet",
    )
    parser.add_argument(
        "-o",
        "--output",
        default=None,
        help="write trust.json to this path (0600) instead of stdout",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = _parse_args(argv)
    try:
        payload = encode(build_trust(args.host, args.fleet_record))
    except (ValueError, KeyError, OSError, CanonicalJsonError) as error:
        print(f"INVALID TRUST GENERATION: {error}", file=sys.stderr)
        return 1
    if args.output is None:
        sys.stdout.buffer.write(payload)
    else:
        descriptor = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(payload)
        os.chmod(args.output, 0o600)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
