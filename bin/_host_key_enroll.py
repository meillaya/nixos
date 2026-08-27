# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
# Folds a freshly-retrieved host private key into the operator's local sops
# store in one step. Run after an ISO auto-enrollment:
#
#   bin/nix-config-host-key-enroll <host-key-file> <hostId>
#
# Derives the public key from the provided private key, confirms it matches the
# host's committed enrollment record, and updates the corresponding
# sops-encrypted secret so the host identity is recoverable and consistent.
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

_REPO = Path(__file__).resolve().parent.parent
_SOPS_FILE = _REPO / "secrets" / "remembrance-keys.yaml"
_SOPS_CONFIG = _REPO / ".sops.yaml"


def _fatal(message: str) -> int:
    print(f"INVALID HOST KEY ENROLL: {message}", file=sys.stderr)
    return 1


def _run(argv: list[str], *, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(argv, capture_output=True, text=True, env=env)


def _derived_public(private_path: Path) -> str:
    result = _run(["ssh-keygen", "-y", "-f", str(private_path)])
    if result.returncode != 0:
        raise ValueError("cannot derive public key from private key")
    return " ".join(result.stdout.strip().split()[:2])


def _sops_env() -> dict[str, str]:
    env = dict(os.environ)
    default_age = Path.home() / ".config" / "sops" / "age" / "keys.txt"
    if "SOPS_AGE_KEY_FILE" not in env and default_age.is_file():
        env["SOPS_AGE_KEY_FILE"] = str(default_age)
    return env


def _decrypt(env: dict[str, str]) -> str:
    result = _run(["sops", "--config", str(_SOPS_CONFIG), "-d", str(_SOPS_FILE)], env=env)
    if result.returncode != 0:
        raise ValueError("failed to decrypt sops store")
    return result.stdout


def _encrypt_in_place(text: str, env: dict[str, str]) -> None:
    # Write the updated plaintext to the real secret path (so the creation-rule
    # regex `secrets/remembrance-keys\.yaml$` matches), encrypt in place, and
    # restore the prior ciphertext if encryption fails.
    prior = _SOPS_FILE.read_bytes() if _SOPS_FILE.is_file() else None
    _SOPS_FILE.write_text(text)
    result = _run(["sops", "--config", str(_SOPS_CONFIG), "-e", "-i", str(_SOPS_FILE)], env=env)
    if result.returncode != 0:
        if prior is not None:
            _SOPS_FILE.write_bytes(prior)
        raise ValueError("failed to re-encrypt sops store")


def _replace_secret(text: str, field: str, private_key: str) -> str:
    block = "\n".join("    " + line for line in private_key.splitlines()) + "\n"
    pattern = re.compile(rf"({re.escape(field)}: \|\n)((?:    .*\n)+)")
    new_text, count = pattern.subn(lambda m: m.group(1) + block, text)
    if count != 1:
        raise ValueError(f"secret field {field!r} not found in sops store")
    return new_text


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print("usage: nix-config-host-key-enroll <host-key-file> <hostId>", file=sys.stderr)
        return 64
    private_path = Path(argv[1])
    host_id = argv[2]
    if not private_path.is_file():
        return _fatal(f"host key file not found: {private_path}")

    try:
        public_key = _derived_public(private_path)
    except ValueError as error:
        return _fatal(str(error))

    enrolled = json.loads((_REPO / "config" / "hosts" / "intake" / f"{host_id}.json").read_text())
    expected = enrolled["publicTrust"]["finalHostPublicKey"]
    if public_key != expected:
        return _fatal(
            f"host key does not match enrolled finalHostPublicKey for {host_id}\n"
            f"  derived : {public_key}\n  enrolled: {expected}\n"
            "Retrieve the host key emitted by the auto-enrollment for this host."
        )

    field = f"{host_id}-final-host"
    env = _sops_env()
    try:
        plain = _decrypt(env)
        updated = _replace_secret(plain, field, private_path.read_text().strip())
        _encrypt_in_place(updated, env)
    except ValueError as error:
        return _fatal(str(error))

    print(f"enrolled {host_id} host key into {_SOPS_FILE.relative_to(_REPO)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))