from __future__ import annotations

import base64
import hashlib
import re

from scripts.hardware.primitives import ContractError, JsonObject, _keys, _string
from scripts.support.canonical_json import JsonValue

_AGE = re.compile(r"^age1[023456789acdefghjklmnpqrstuvwxyz]{58}$")
_SHA256 = re.compile(r"^[0-9a-f]{64}$")
_KEY = re.compile(r"^ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA[A-Za-z0-9+/]{32,}$")


def _key_fingerprint(value: JsonValue, label: str) -> str:
    key = _string(value, _KEY, label)
    try:
        payload = base64.b64decode(key.split(" ")[1], validate=True)
    except (ValueError, IndexError) as error:
        raise ContractError(f"{label} encoding") from error
    if len(payload) != 51 or not payload.startswith(b"\x00\x00\x00\x0bssh-ed25519\x00\x00\x00\x20"):
        raise ContractError(f"{label} key blob")
    return "SHA256:" + base64.b64encode(hashlib.sha256(payload).digest()).decode("ascii").rstrip("=")


def _sha(value: JsonValue, label: str) -> str:
    return _string(value, _SHA256, label)


def _sorted_unique(rows: JsonValue, key: str, label: str) -> list[JsonObject]:
    if not isinstance(rows, list) or any(not isinstance(row, dict) for row in rows):
        raise ContractError(f"{label} list")
    typed = [row for row in rows if isinstance(row, dict)]
    values = [row.get(key) for row in typed]
    if any(not isinstance(item, str) for item in values):
        raise ContractError(f"{label} key")
    string_values = [item for item in values if isinstance(item, str)]
    if string_values != sorted(string_values) or len(set(string_values)) != len(string_values):
        raise ContractError(f"{label} ordering")
    return typed


def validate_trust(public: JsonValue, secret: JsonValue) -> None:
    public_row = _keys(public, {"state"}, "publicTrust") if isinstance(public, dict) and public.get("state") == "disabled" else _keys(public, {"state", "installAuthorizerPrincipal", "installAuthorizerPublicKey", "installAuthorizerFingerprint", "permanentLoginPublicKey", "permanentLoginFingerprint", "finalHostPublicKey", "finalHostFingerprint"}, "publicTrust")
    if public_row["state"] not in {"disabled", "enrolled"}:
        raise ContractError("publicTrust state")
    if public_row["state"] == "enrolled":
        _string(public_row["installAuthorizerPrincipal"], re.compile(r"^[A-Za-z0-9._-]+$"), "publicTrust.installAuthorizerPrincipal")
        key_names = ("installAuthorizerPublicKey", "permanentLoginPublicKey", "finalHostPublicKey")
        fingerprint_names = ("installAuthorizerFingerprint", "permanentLoginFingerprint", "finalHostFingerprint")
        for key_name, fingerprint_name in zip(key_names, fingerprint_names):
            if _key_fingerprint(public_row[key_name], f"publicTrust.{key_name}") != public_row[fingerprint_name]:
                raise ContractError("publicTrust fingerprint correspondence")
        fingerprints = [public_row[name] for name in fingerprint_names]
        if any(not isinstance(item, str) or not item.startswith("SHA256:") for item in fingerprints) or len(set(fingerprints)) != 3:
            raise ContractError("publicTrust fingerprints")
        key_values = [public_row[name] for name in key_names]
        if any(not isinstance(item, str) for item in key_values) or len({item for item in key_values if isinstance(item, str)}) != 3:
            raise ContractError("publicTrust key reuse")
    secret_row = _keys(secret, {"state"}, "secretTrust") if isinstance(secret, dict) and secret.get("state") == "disabled" else _keys(secret, {"state", "hostAgeRecipient", "recoveryAgeRecipient", "ciphertexts"}, "secretTrust")
    if secret_row["state"] not in {"disabled", "enrolled"}:
        raise ContractError("secretTrust state")
    if secret_row["state"] == "enrolled":
        _string(secret_row["hostAgeRecipient"], _AGE, "hostAgeRecipient")
        _string(secret_row["recoveryAgeRecipient"], _AGE, "recoveryAgeRecipient")
        if secret_row["hostAgeRecipient"] == secret_row["recoveryAgeRecipient"]:
            raise ContractError("age recipient reuse")
        rows = _sorted_unique(secret_row["ciphertexts"], "path", "ciphertexts")
        if not rows:
            raise ContractError("ciphertexts empty")
        for row in rows:
            _keys(row, {"path", "sha256"}, "ciphertext")
            _string(row["path"], re.compile(r"^secrets/[A-Za-z0-9][A-Za-z0-9._-]*(/[A-Za-z0-9][A-Za-z0-9._-]*)*$"), "ciphertext.path")
            _sha(row["sha256"], "ciphertext.sha256")
