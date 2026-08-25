from __future__ import annotations

import hashlib
import io
import os
from pathlib import Path

from .contracts import ContractError, canonical, parse_canonical, require_host, require_sha


def read_frame(stream: io.BufferedIOBase | io.BytesIO, maximum: int = 16384) -> bytes:
    line = stream.readline(7)
    if not line.endswith(b"\n"):
        raise ContractError("identity-frame-length")
    raw_length = line[:-1]
    if not raw_length.isdigit() or (len(raw_length) > 1 and raw_length.startswith(b"0")):
        raise ContractError("identity-frame-length")
    length = int(raw_length)
    if not 1 <= length <= maximum:
        raise ContractError("identity-frame-length")
    payload = stream.read(length)
    if len(payload) != length:
        raise ContractError("identity-frame-truncated")
    return payload


def stage_identity(target: Path, transaction_id: str, host_id: str, frames: list[bytes]) -> Path:
    require_host(host_id)
    if not transaction_id or "/" in transaction_id or ".." in transaction_id:
        raise ContractError("identity-transaction")
    if not frames or any(not isinstance(frame, bytes) or not frame for frame in frames):
        raise ContractError("identity-frames")
    payload = b"".join(frames)
    ready = target / "var/lib/nix-config/identity" / transaction_id / ".ready"
    ready.parent.mkdir(mode=0o700, parents=True, exist_ok=False)
    temporary = ready.with_name(".ready.tmp")
    descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    try:
        os.write(descriptor, canonical({"hostId": host_id, "payloadSha256": hashlib.sha256(payload).hexdigest()}))
        os.fsync(descriptor)
    finally:
        os.close(descriptor)
    os.replace(temporary, ready)
    directory = os.open(ready.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC)
    try:
        os.fsync(directory)
    finally:
        os.close(directory)
    return ready


def activate_identity(target: Path, transaction_id: str, host_id: str, expected_payload_sha256: str) -> Path:
    require_sha(expected_payload_sha256, "identity-payload")
    ready = target / "var/lib/nix-config/identity" / transaction_id / ".ready"
    if ready.is_symlink() or not ready.is_file():
        raise ContractError("identity-ready")
    value = parse_canonical(ready.read_bytes())
    if not isinstance(value, dict) or set(value) != {"hostId", "payloadSha256"} or value["hostId"] != require_host(host_id) or value["payloadSha256"] != expected_payload_sha256:
        raise ContractError("identity-correspondence")
    activated = ready.parent / "activation.json"
    if activated.is_symlink() or activated.exists():
        raise ContractError("identity-activation-collision")
    temporary = activated.with_name("activation.json.tmp")
    descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    try:
        os.write(descriptor, canonical({"hostId": host_id, "state": "identity-ready"}))
        os.fsync(descriptor)
    finally:
        os.close(descriptor)
    os.replace(temporary, activated)
    directory = os.open(activated.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC)
    try:
        os.fsync(directory)
    finally:
        os.close(directory)
    return activated
