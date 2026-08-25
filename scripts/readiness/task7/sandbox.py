from __future__ import annotations

import hashlib
import os
import stat
from dataclasses import dataclass, field
from pathlib import Path

from .contracts import ContractError, JsonObject, TOOLS, digest, parse_canonical, validate_tool_sandbox


@dataclass(frozen=True, slots=True)
class Notification:
    kind: str
    ordinal: int
    path: str
    fd: int
    flags: int
    dirfd: str
    role: str | None = None

    def json(self) -> JsonObject:
        return {
            "kind": self.kind,
            "ordinal": self.ordinal,
            "path": self.path,
            "fd": self.fd,
            "flags": self.flags,
            "dirfd": self.dirfd,
            "role": self.role,
        }


@dataclass(slots=True)
class ToolBroker:
    manifest: JsonObject
    private_root: Path
    tool: str
    state: str = "setup"
    read_cursor: int = 0
    device_cursor: int = 0
    notifications: list[Notification] = field(default_factory=list)
    writes: int = 0
    _row: JsonObject = field(init=False, repr=False)

    def __post_init__(self) -> None:
        validate_tool_sandbox(self.manifest)
        if self.tool not in TOOLS:
            raise ContractError("sandbox-tool")
        if not self.private_root.is_dir() or self.private_root.is_symlink():
            raise ContractError("sandbox-root")
        tools = self.manifest["tools"]
        if not isinstance(tools, list):
            raise ContractError("tool-sandbox-shape")
        for value in tools:
            if isinstance(value, dict) and value.get("tool") == self.tool:
                self._row = value
                break
        else:
            raise ContractError("sandbox-tool")

    def executable_transition(self) -> None:
        if self.state != "setup":
            raise ContractError("sandbox-exec-state")
        self.state = "running"

    def read(self, ordinal: int, path: str, fd: int, flags: int, dirfd: str) -> None:
        if self.state != "running":
            raise ContractError("sandbox-read-state")
        rows = self._row["readRows"]
        if not isinstance(rows, list):
            raise ContractError("tool-read-rows")
        if self.read_cursor >= len(rows):
            raise ContractError("sandbox-extra-read")
        row = rows[self.read_cursor]
        if not isinstance(row, dict):
            raise ContractError("tool-read-row")
        if (
            row["ordinal"],
            row["requestedPath"],
            row["injectedFd"],
            row["allowedFlags"],
            row["dirfdClass"],
        ) != (ordinal, path, fd, flags, dirfd):
            raise ContractError("sandbox-read-order")
        if row["result"] == "enoent":
            raise ContractError("sandbox-unexpected-enoent")
        relative_path = row["relativePath"]
        if not isinstance(relative_path, str):
            raise ContractError("tool-read-path")
        target = self.private_root / relative_path
        try:
            resolved = target.resolve(strict=True)
            resolved.relative_to(self.private_root.resolve())
        except (FileNotFoundError, ValueError) as error:
            raise ContractError("sandbox-read-target") from error
        metadata = os.lstat(resolved)
        file_type = row["fileType"]
        if file_type == "regular" and not stat.S_ISREG(metadata.st_mode):
            raise ContractError("sandbox-read-type")
        if file_type == "directory" and not stat.S_ISDIR(metadata.st_mode):
            raise ContractError("sandbox-read-type")
        if file_type == "symlink" and not stat.S_ISLNK(metadata.st_mode):
            raise ContractError("sandbox-read-type")
        if file_type != "directory":
            raw = os.readlink(resolved).encode() if stat.S_ISLNK(metadata.st_mode) else resolved.read_bytes()
            if hashlib.sha256(raw).hexdigest() != row["sha256"]:
                raise ContractError("sandbox-read-digest")
        self.read_cursor += 1
        self.notifications.append(Notification("read", ordinal, path, fd, flags, dirfd))

    def device(self, ordinal: int, path: str, fd: int, flags: int, dirfd: str, role: str, access: str) -> None:
        if self.state != "running":
            raise ContractError("sandbox-device-state")
        rows = self._row["deviceRows"]
        if not isinstance(rows, list):
            raise ContractError("tool-device-rows")
        if self.device_cursor >= len(rows):
            raise ContractError("sandbox-extra-device")
        row = rows[self.device_cursor]
        if not isinstance(row, dict):
            raise ContractError("tool-device-row")
        if (
            row["ordinal"],
            row["requestedPath"],
            row["injectedFd"],
            row["requestedFlags"],
            row["dirfdClass"],
            row["claimRole"],
            row["access"],
        ) != (ordinal, path, fd, flags, dirfd, role, access):
            raise ContractError("sandbox-device-order")
        self.device_cursor += 1
        if access == "write":
            self.writes += 1
        self.notifications.append(Notification("device", ordinal, path, fd, flags, dirfd, role))

    def exit(self, status: int = 0) -> JsonObject:
        if self.state != "running" or status != 0:
            raise ContractError("sandbox-exit")
        read_rows = self._row["readRows"]
        device_rows = self._row["deviceRows"]
        if not isinstance(read_rows, list) or not isinstance(device_rows, list):
            raise ContractError("tool-sandbox-row")
        if self.read_cursor != len(read_rows) or self.device_cursor != len(device_rows):
            raise ContractError("sandbox-missing-notification")
        self.state = "exited"
        return {
            "tool": self.tool,
            "state": self.state,
            "readNotifications": self.read_cursor,
            "deviceNotifications": self.device_cursor,
            "writes": self.writes,
            "traceDigest": digest([notification.json() for notification in self.notifications]),
        }


def private_node_tree(root: Path, disk_by_id: str, major: int, minor: int) -> Path:
    if not disk_by_id or "/" in disk_by_id or ".." in disk_by_id:
        raise ContractError("private-node-name")
    root.mkdir(mode=0o700, parents=True, exist_ok=False)
    by_id = root / "disk" / "by-id"
    by_id.mkdir(mode=0o700, parents=True, exist_ok=False)
    path = by_id / disk_by_id
    os.mknod(path, stat.S_IFBLK | 0o600, os.makedev(major, minor))
    return path


def sandbox_manifest(path: Path) -> JsonObject:
    value = parse_canonical(path.read_bytes())
    if not isinstance(value, dict):
        raise ContractError("tool-sandbox-shape")
    validate_tool_sandbox(value)
    return value
