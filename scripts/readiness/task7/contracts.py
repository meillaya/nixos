from __future__ import annotations

import hashlib
import ipaddress
import json
import os
import re
import stat
from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path
from typing import Final, Protocol, TypeAlias


class ContractError(ValueError):
    pass


JsonScalar: TypeAlias = None | bool | int | float | str
Json: TypeAlias = JsonScalar | list["Json"] | dict[str, "Json"]
JsonObject: TypeAlias = dict[str, Json]


class _JsonDecoder(Protocol):
    def decode(self, s: str) -> Json: ...


HOST_ID: Final = re.compile(r"^[a-z][a-z0-9-]{0,63}$")
DISK_BASENAME: Final = re.compile(r"^[A-Za-z0-9._:+-]{1,255}$")
SHA256: Final = re.compile(r"^[0-9a-f]{64}$")
BOOT_ID: Final = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
)
TRANSACTION_ID: Final = re.compile(r"^[0-9a-f]{48}$")
STATES: Final = (
    "prepared",
    "erase-approved",
    "partition-writer-in-flight",
    "partitioned",
    "format-writer-in-flight:part1",
    "formatted:part1",
    "format-writer-in-flight:part2",
    "formatted:part2",
    "provisioned",
    "identity-staged",
    "identity-ready",
    "verification-snapshot-ready",
    "recovery-reboot-approved",
    "recovery-esp-budget-verified",
    "recovery-reboot-consumed",
    "recovery-boot-entry-in-flight",
    "recovery-boot-pending",
    "recovery-boot-verified",
    "rollback-transaction-prepared",
    "boot-verified",
)
IN_FLIGHT: Final = frozenset(
    {
        "partition-writer-in-flight",
        "format-writer-in-flight:part1",
        "format-writer-in-flight:part2",
        "recovery-boot-entry-in-flight",
    }
)
TOOLS: Final = ("sfdisk", "mkfs.vfat", "mkfs.btrfs")
EXEC_SENTINEL: Final = 'execveat(1023,"",...,AT_EMPTY_PATH)'
USER_NOTIFICATIONS: Final = frozenset(
    {"USER_NOTIF:open", "USER_NOTIF:openat", "USER_NOTIF:openat2"}
)
SYSCALL_FD_CREATORS: Final = frozenset(
    {
        "socket",
        "socketpair",
        "pipe",
        "pipe2",
        "eventfd",
        "eventfd2",
        "signalfd",
        "signalfd4",
        "timerfd_create",
        "epoll_create",
        "epoll_create1",
        "inotify_init",
        "inotify_init1",
        "fanotify_init",
        "userfaultfd",
        "memfd_create",
        "pidfd_open",
        "dup",
        "dup2",
        "dup3",
        "fcntl:F_DUPFD",
        "fcntl:F_DUPFD_CLOEXEC",
        "setrlimit",
        "prlimit64",
    }
)


def _pairs(pairs: list[tuple[str, Json]]) -> dict[str, Json]:
    result: dict[str, Json] = {}
    for key, value in pairs:
        if key in result:
            raise ContractError("duplicate-json-key")
        result[key] = value
    return result


def _reject_nonfinite(_: str) -> Json:
    raise ContractError("json-nonfinite")


def _decode_json(decoder: _JsonDecoder, text: str) -> Json:
    return decoder.decode(text)


def load_json(raw: bytes) -> Json:

    if raw.startswith(b"\xef\xbb\xbf"):
        raise ContractError("json-bom")
    try:
        text = raw.decode("utf-8", errors="strict")
        value = _decode_json(
            json.JSONDecoder(
                object_pairs_hook=_pairs,
                parse_constant=_reject_nonfinite,
            ),
            text,
        )
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ContractError("json-invalid") from error
    return value


def canonical(value: Json) -> bytes:

    return (json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n").encode(
        "utf-8"
    )


def parse_canonical(raw: bytes) -> Json:
    value = load_json(raw)
    if canonical(value) != raw:
        raise ContractError("json-not-canonical")
    return value


def digest(value: Json) -> str:
    return hashlib.sha256(canonical(value)).hexdigest()


def sha256_bytes(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def require_sha(value: object, field: str) -> str:
    if not isinstance(value, str) or SHA256.fullmatch(value) is None:
        raise ContractError(f"{field}-sha256")
    return value


def require_disk_basename(value: object) -> str:
    if not isinstance(value, str) or DISK_BASENAME.fullmatch(value) is None:
        raise ContractError("disk-by-id")
    if value in (".", ".."):
        raise ContractError("disk-by-id")
    if re.search(r"-part[0-9]+$", value):
        raise ContractError("disk-partition")
    return value


def disk_path(value: object) -> str:
    if isinstance(value, str) and value.startswith("/dev/disk/by-id/"):
        value = value.removeprefix("/dev/disk/by-id/")
    return f"/dev/disk/by-id/{require_disk_basename(value)}"


@dataclass(frozen=True, slots=True)
class DeviceFacts:
    disk_by_id: str
    size_bytes: int
    logical_sector_bytes: int
    model_sha256: str
    serial_sha256: str
    major: int
    minor: int
    canonical_sysfs_path: str
    parent_sysfs_path: str
    partition: bool = False
    mounted: bool = False
    swap: bool = False
    holders: tuple[str, ...] = ()

    @classmethod
    def from_mapping(cls, value: Mapping[str, Json]) -> "DeviceFacts":
        required = {
            "byId",
            "sizeBytes",
            "logicalSectorBytes",
            "modelSha256",
            "serialSha256",
            "major",
            "minor",
            "canonicalSysfsPath",
            "parentSysfsPath",
            "partition",
            "mounted",
            "swap",
            "holders",
        }
        if set(value) != required:
            raise ContractError("device-facts-shape")
        by_id = disk_path(value["byId"])
        size_bytes = value["sizeBytes"]
        if not isinstance(size_bytes, int) or isinstance(size_bytes, bool) or size_bytes < 0:
            raise ContractError("device-sizeBytes")
        logical_sector_bytes = value["logicalSectorBytes"]
        if (
            not isinstance(logical_sector_bytes, int)
            or isinstance(logical_sector_bytes, bool)
            or logical_sector_bytes < 0
        ):
            raise ContractError("device-logicalSectorBytes")
        major = value["major"]
        if not isinstance(major, int) or isinstance(major, bool) or major < 0:
            raise ContractError("device-major")
        minor = value["minor"]
        if not isinstance(minor, int) or isinstance(minor, bool) or minor < 0:
            raise ContractError("device-minor")
        if size_bytes <= 0 or logical_sector_bytes not in (512, 4096):
            raise ContractError("device-geometry")
        model_sha256 = require_sha(value["modelSha256"], "device-modelSha256")
        serial_sha256 = require_sha(value["serialSha256"], "device-serialSha256")
        canonical_sysfs_path = value["canonicalSysfsPath"]
        parent_sysfs_path = value["parentSysfsPath"]
        if not isinstance(canonical_sysfs_path, str) or not canonical_sysfs_path.startswith("/sys/"):
            raise ContractError("device-sysfs")
        if not isinstance(parent_sysfs_path, str) or not parent_sysfs_path.startswith("/sys/"):
            raise ContractError("device-parent")
        partition = value["partition"]
        mounted = value["mounted"]
        swap = value["swap"]
        if not isinstance(partition, bool) or not isinstance(mounted, bool) or not isinstance(swap, bool):
            raise ContractError("device-flags")
        holders = value["holders"]
        if not isinstance(holders, list) or any(
            not isinstance(item, str) or not item for item in holders
        ):
            raise ContractError("device-holders")
        holder_names = [item for item in holders if isinstance(item, str)]
        if holders != sorted(set(holder_names), key=str.encode):
            raise ContractError("device-holders-order")
        return cls(
            by_id,
            size_bytes,
            logical_sector_bytes,
            model_sha256,
            serial_sha256,
            major,
            minor,
            canonical_sysfs_path,
            parent_sysfs_path,
            partition,
            mounted,
            swap,
            tuple(holder_names),
        )

    @property
    def basename(self) -> str:
        return self.disk_by_id.removeprefix("/dev/disk/by-id/")

    def identity_projection(self) -> dict[str, Json]:
        return {
            "diskById": self.basename,
            "sizeBytes": self.size_bytes,
            "logicalSectorBytes": self.logical_sector_bytes,
            "modelSha256": self.model_sha256,
            "serialSha256": self.serial_sha256,
        }

    def identity_digest(self) -> str:
        return digest(self.identity_projection())

    def binding_digest(self, boot_id: str) -> str:
        if BOOT_ID.fullmatch(boot_id) is None:
            raise ContractError("boot-id")
        return digest(
            {
                "bootId": boot_id,
                "diskIdentitySha256": self.identity_digest(),
                "major": self.major,
                "minor": self.minor,
                "canonicalSysfsPath": self.canonical_sysfs_path,
            }
        )

    def writable_blocked(self) -> bool:
        return self.mounted or self.swap or bool(self.holders)


def _safe_sysfs(value: object) -> str:
    if not isinstance(value, str) or not value.startswith("/sys/"):
        raise ContractError("sysfs-path")
    if "\x00" in value or ".." in Path(value).parts:
        raise ContractError("sysfs-path")
    return value


def resolve_fixture(topology: Path, by_id: str) -> DeviceFacts:

    requested = disk_path(by_id)
    try:
        payload = parse_canonical(topology.read_bytes())
    except OSError as error:
        raise ContractError("topology-unreadable") from error
    if not isinstance(payload, dict) or set(payload) != {"devices", "links"}:
        raise ContractError("topology-shape")
    links = payload["links"]
    devices = payload["devices"]
    if not isinstance(links, dict) or not isinstance(devices, list):
        raise ContractError("topology-shape")
    link = links.get(requested)
    if not isinstance(link, dict) or set(link) != {"target", "kind"}:
        raise ContractError("by-id-link")
    target = link["target"]
    if link["kind"] != "symlink" or not isinstance(target, str) or "\x00" in target:
        raise ContractError("by-id-link")
    if target.startswith("/") or target.startswith("/proc") or target.startswith("/sys"):
        raise ContractError("by-id-outside-dev")
    resolved = (Path("/dev/disk/by-id") / target).resolve()
    try:
        resolved.relative_to(Path("/dev"))
    except ValueError as error:
        raise ContractError("by-id-outside-dev") from error
    if "magic" in target or target.startswith("../proc") or target.startswith("../sys"):
        raise ContractError("by-id-magic-link")
    candidates = [row for row in devices if isinstance(row, dict) and row.get("path") == str(resolved)]
    if len(candidates) != 1:
        raise ContractError("by-id-device")
    row = candidates[0]
    if set(row) != {
        "path",
        "byId",
        "sizeBytes",
        "logicalSectorBytes",
        "modelSha256",
        "serialSha256",
        "major",
        "minor",
        "canonicalSysfsPath",
        "parentSysfsPath",
        "partition",
        "mounted",
        "swap",
        "holders",
    }:
        raise ContractError("device-row-shape")
    if row["byId"] != requested:
        raise ContractError("by-id-rebind")
    facts = DeviceFacts.from_mapping(
        {
            "byId": row["byId"],
            "sizeBytes": row["sizeBytes"],
            "logicalSectorBytes": row["logicalSectorBytes"],
            "modelSha256": row["modelSha256"],
            "serialSha256": row["serialSha256"],
            "major": row["major"],
            "minor": row["minor"],
            "canonicalSysfsPath": _safe_sysfs(row["canonicalSysfsPath"]),
            "parentSysfsPath": _safe_sysfs(row["parentSysfsPath"]),
            "partition": row["partition"],
            "mounted": row["mounted"],
            "swap": row["swap"],
            "holders": row["holders"],
        }
    )
    if facts.partition:
        raise ContractError("device-is-partition")
    if facts.writable_blocked():
        raise ContractError("device-busy")
    return facts


def require_distinct_devices(*devices: DeviceFacts) -> None:
    if len(devices) < 2:
        return
    for left_index, left in enumerate(devices):
        for right in devices[left_index + 1 :]:
            if (left.major, left.minor) == (right.major, right.minor):
                raise ContractError("device-collision")
            if left.parent_sysfs_path == right.parent_sysfs_path:
                raise ContractError("device-parent-collision")


def revalidate(original: DeviceFacts, current: DeviceFacts) -> None:
    if original != current:
        raise ContractError("device-rebound")


def canonical_endpoint(address: object, port: object) -> tuple[str, int]:
    if not isinstance(address, str) or not isinstance(port, int) or isinstance(port, bool):
        raise ContractError("endpoint")
    if any(ord(char) < 32 or char.isspace() for char in address):
        raise ContractError("endpoint")
    try:
        parsed = ipaddress.ip_address(address)
    except ValueError as error:
        raise ContractError("endpoint") from error
    if str(parsed) != address or not 1 <= port <= 65535:
        raise ContractError("endpoint")
    return str(parsed), port


def require_host(value: object) -> str:
    if not isinstance(value, str) or HOST_ID.fullmatch(value) is None:
        raise ContractError("host-id")
    return value


def require_transaction(value: object) -> str:
    if not isinstance(value, str) or TRANSACTION_ID.fullmatch(value) is None:
        raise ContractError("transaction-id")
    return value


def ensure_safe_relative(value: object) -> str:
    if not isinstance(value, str) or not value or value.startswith("/"):
        raise ContractError("relative-path")
    path = Path(value)
    if any(part in ("", ".", "..") for part in path.parts) or "\x00" in value:
        raise ContractError("relative-path")
    return value


def mode_owner(path: Path, mode: int, uid: int = 0, gid: int = 0) -> None:
    metadata = os.lstat(path)
    if not stat.S_ISREG(metadata.st_mode) or stat.S_IMODE(metadata.st_mode) != mode:
        raise ContractError("file-mode")
    if metadata.st_uid != uid or metadata.st_gid != gid or metadata.st_nlink != 1:
        raise ContractError("file-owner")


def exact_keys(value: Json, expected: set[str], label: str) -> JsonObject:
    if not isinstance(value, dict) or set(value) != expected:
        raise ContractError(f"{label}-shape")
    return value


def disk_layout(disk_by_id: object) -> dict[str, Json]:
    device = disk_path(disk_by_id)
    return {
        "type": "disk",
        "device": device,
        "content": {
            "type": "gpt",
            "partitions": {
                "ESP": {
                    "type": "EF00",
                    "size": "1024M",
                    "content": {
                        "type": "filesystem",
                        "format": "vfat",
                        "extraArgs": ["-F", "32"],
                        "mountpoint": "/boot",
                        "mountOptions": ["umask=0077"],
                    },
                },
                "root": {
                    "size": "100%",
                    "content": {
                        "type": "btrfs",
                        "extraArgs": ["-f"],
                        "subvolumes": {
                            name: {
                                "mountpoint": mount,
                                "mountOptions": ["compress=zstd:3", "noatime"],
                            }
                            for name, mount in (
                                ("@root", "/"),
                                ("@home", "/home"),
                                ("@nix", "/nix"),
                                ("@log", "/var/log"),
                            )
                        },
                    },
                },
            },
        },
    }


def validate_disk_layout(value: Json, disk_by_id: object | None = None) -> None:
    if not isinstance(value, dict) or set(value) != {"type", "device", "content"}:
        raise ContractError("disko-shape")
    if not isinstance(value["device"], str):
        raise ContractError("disko-device")
    expected = disk_layout(value["device"].removeprefix("/dev/disk/by-id/"))
    if value != expected:
        raise ContractError("disko-layout")
    if disk_by_id is not None and value["device"] != disk_path(disk_by_id):
        raise ContractError("disko-device-binding")


def validate_storage_object(value: Json) -> None:
    if not isinstance(value, dict) or set(value) != {"profile", "diskById", "expected"}:
        raise ContractError("storage-object")
    if value["profile"] != "single-gpt-btrfs":
        raise ContractError("storage-profile")
    require_disk_basename(value["diskById"])
    expected = value["expected"]
    if not isinstance(expected, dict) or set(expected) != {
        "sizeBytes",
        "logicalSectorBytes",
        "modelSha256",
        "serialSha256",
    }:
        raise ContractError("storage-expected")
    if not isinstance(expected["sizeBytes"], int) or expected["sizeBytes"] <= 0:
        raise ContractError("storage-size")
    if expected["logicalSectorBytes"] not in (512, 4096):
        raise ContractError("storage-sector")
    require_sha(expected["modelSha256"], "storage-model")
    require_sha(expected["serialSha256"], "storage-serial")


def _sorted_rows(rows: Json, label: str) -> list[JsonObject]:
    if not isinstance(rows, list) or any(not isinstance(row, dict) for row in rows):
        raise ContractError(f"{label}-rows")
    objects = [row for row in rows if isinstance(row, dict)]
    if objects != sorted(objects, key=canonical):
        raise ContractError(f"{label}-order")
    return objects


def validate_tool_sandbox(value: Json) -> None:
    if not isinstance(value, dict) or set(value) != {"schemaVersion", "tools"}:
        raise ContractError("tool-sandbox-shape")
    if value["schemaVersion"] != 1:
        raise ContractError("tool-sandbox-version")
    tools = _sorted_rows(value["tools"], "tool-sandbox")
    if [row.get("tool") for row in tools] != sorted(TOOLS, key=str.encode):
        raise ContractError("tool-sandbox-tools")
    for row in tools:
        expected = {
            "tool",
            "executablePath",
            "executableNarHash",
            "argv",
            "stdinSha256",
            "syscalls",
            "readRows",
            "deviceRows",
        }
        if set(row) != expected or row["tool"] not in TOOLS:
            raise ContractError("tool-sandbox-row")
        if not isinstance(row["executablePath"], str) or not row["executablePath"].startswith("/nix/store/"):
            raise ContractError("tool-sandbox-executable")
        require_sha(row["executableNarHash"], "tool-sandbox-executable")
        require_sha(row["stdinSha256"], "tool-sandbox-stdin")
        if not isinstance(row["argv"], list) or not all(isinstance(arg, str) for arg in row["argv"]):
            raise ContractError("tool-sandbox-argv")
        syscall_values = row["syscalls"]
        if not isinstance(syscall_values, list) or any(
            not isinstance(name, str) for name in syscall_values
        ):
            raise ContractError("tool-sandbox-syscalls")
        syscalls = [name for name in syscall_values if isinstance(name, str)]
        if syscall_values != sorted(set(syscalls)):
            raise ContractError("tool-sandbox-syscalls")
        if "KILL_PROCESS" not in syscalls or not USER_NOTIFICATIONS <= set(syscalls):
            raise ContractError("tool-sandbox-default")
        if syscalls.count(EXEC_SENTINEL) != 1:
            raise ContractError("tool-sandbox-exec-sentinel")
        if any(
            isinstance(name, str)
            and (name.startswith("USER_NOTIF:") and name not in USER_NOTIFICATIONS)
            for name in syscalls
        ):
            raise ContractError("tool-sandbox-notification")
        if any(name in syscalls for name in SYSCALL_FD_CREATORS):
            raise ContractError("tool-sandbox-fd-creator")
        if any(
            name in syscalls
            for name in (
                "execve",
                "clone",
                "fork",
                "vfork",
                "mount",
                "ptrace",
                "bpf",
                "io_uring_setup",
                "io_uring_enter",
                "io_uring_register",
                "unshare",
                "setns",
                "setrlimit",
                "prlimit64",
            )
        ):
            raise ContractError("tool-sandbox-syscall")
        _validate_read_rows(row["readRows"])
        _validate_device_rows(row["deviceRows"], row["tool"])


def _validate_read_rows(rows: Json) -> None:
    if not isinstance(rows, list):
        raise ContractError("tool-read-rows")
    ordinals: list[int] = []
    fds: set[int] = set()
    for row in rows:
        if not isinstance(row, dict):
            raise ContractError("tool-read-row")
        expected = {
            "ordinal",
            "requestedPath",
            "dirfdClass",
            "result",
            "root",
            "relativePath",
            "fileType",
            "size",
            "sha256",
            "allowedFlags",
            "injectedFd",
            "newfdFlags",
        }
        if set(row) != expected:
            raise ContractError("tool-read-row")
        ordinal = row["ordinal"]
        if not isinstance(ordinal, int) or ordinal < 0:
            raise ContractError("tool-read-ordinal")
        ordinals.append(ordinal)
        dirfd_class = row["dirfdClass"]
        root = row["root"]
        result = row["result"]
        requested_path = row["requestedPath"]
        relative_path = row["relativePath"]
        allowed_flags = row["allowedFlags"]
        if dirfd_class not in ("cwd", "injected") or root not in ("store", "proc", "sys"):
            raise ContractError("tool-read-root")
        if result not in ("fd", "enoent"):
            raise ContractError("tool-read-result")
        if not isinstance(requested_path, str) or not isinstance(relative_path, str):
            raise ContractError("tool-read-path")
        if (
            not requested_path.startswith("/")
            or "\x00" in requested_path
            or any(part in ("", ".", "..") for part in Path(relative_path).parts)
            or relative_path.startswith("/")
        ):
            raise ContractError("tool-read-path")
        if root == "store" and not requested_path.startswith("/nix/store/"):
            raise ContractError("tool-read-root")
        if root == "proc" and not requested_path.startswith("/proc/"):
            raise ContractError("tool-read-root")
        if root == "sys" and not requested_path.startswith("/sys/"):
            raise ContractError("tool-read-root")
        if result == "enoent":
            if (
                row["injectedFd"] is not None
                or row["newfdFlags"] is not None
                or row["size"] is not None
                or row["sha256"] is not None
                or row["fileType"] is not None
            ):
                raise ContractError("tool-read-enoent")
        else:
            fd = row["injectedFd"]
            if not isinstance(fd, int) or not 64 <= fd <= 511 or fd in fds:
                raise ContractError("tool-read-fd")
            fds.add(fd)
            size = row["size"]
            if not isinstance(size, int) or size < 0:
                raise ContractError("tool-read-size")
            file_type = row["fileType"]
            if file_type not in ("regular", "directory", "symlink"):
                raise ContractError("tool-read-type")
            if file_type == "directory" and row["sha256"] is not None:
                raise ContractError("tool-read-directory")
            if file_type != "directory":
                require_sha(row["sha256"], "tool-read")
            if (
                not isinstance(allowed_flags, int)
                or row["newfdFlags"] not in (0, 524288)
                or row["newfdFlags"] != allowed_flags & 524288
            ):
                raise ContractError("tool-read-flags")
        if not isinstance(allowed_flags, int) or allowed_flags not in (0, 524288):
            raise ContractError("tool-read-flags")
    if ordinals != list(range(len(ordinals))):
        raise ContractError("tool-read-order")


def _validate_device_rows(rows: Json, tool: str) -> None:
    if not isinstance(rows, list):
        raise ContractError("tool-device-rows")
    ordinals: list[int] = []
    fds: set[int] = set()
    for row in rows:
        if not isinstance(row, dict):
            raise ContractError("tool-device-row")
        expected = {
            "ordinal",
            "requestedPath",
            "dirfdClass",
            "requestedFlags",
            "injectedFd",
            "newfdFlags",
            "claimRole",
            "access",
        }
        if set(row) != expected:
            raise ContractError("tool-device-row")
        ordinal = row["ordinal"]
        if not isinstance(ordinal, int) or ordinal < 0:
            raise ContractError("tool-device-ordinal")
        ordinals.append(ordinal)
        fd = row["injectedFd"]
        if not isinstance(fd, int) or not 512 <= fd <= 767 or fd in fds:
            raise ContractError("tool-device-fd")
        fds.add(fd)
        claim_role = row["claimRole"]
        access = row["access"]
        requested_path = row["requestedPath"]
        requested_flags = row["requestedFlags"]
        if row["dirfdClass"] not in ("cwd", "injected") or claim_role not in ("whole", "part1", "part2"):
            raise ContractError("tool-device-row")
        if tool == "sfdisk" and claim_role != "whole":
            raise ContractError("tool-device-role")
        if tool == "mkfs.vfat" and claim_role != "part1":
            raise ContractError("tool-device-role")
        if tool == "mkfs.btrfs" and claim_role != "part2":
            raise ContractError("tool-device-role")
        if access not in ("read", "write"):
            raise ContractError("tool-device-access")
        if not isinstance(requested_path, str) or not requested_path.startswith("/run/nix-config-device/"):
            raise ContractError("tool-device-path")
        if not isinstance(requested_flags, int) or requested_flags < 0:
            raise ContractError("tool-device-flags")
        if requested_flags not in (524288, 524418):
            raise ContractError("tool-device-flags")
        if row["newfdFlags"] not in (0, 524288) or row["newfdFlags"] != requested_flags & 524288:
            raise ContractError("tool-device-flags")
        if access == "read" and requested_flags != 524288:
            raise ContractError("tool-device-flags")
        if access == "write" and requested_flags != 524418:
            raise ContractError("tool-device-flags")
    if ordinals != list(range(len(ordinals))):
        raise ContractError("tool-device-order")


def validate_manifest(value: Json) -> None:
    expected = {
        "schemaVersion",
        "transactionId",
        "sourceGitCommit",
        "flakeLockSha256",
        "hostId",
        "target",
        "declarationDigest",
        "installerBootId",
        "installerDeviceBindingSha256",
        "installerSystemPath",
        "installerTopLevelNarHash",
        "installerClosureDigest",
        "manifestRequestSha256",
        "recoverySystemPath",
        "recoveryTopLevelNarHash",
        "recoveryClosureDigest",
        "candidateSystemPath",
        "candidateTopLevelNarHash",
        "candidateClosureDigest",
        "isoArtifactSizeBytes",
        "isoSha256",
        "payloadManifestSha256",
        "releaseSignerFingerprint",
        "provisioningPayloadSha256",
        "diskById",
        "diskIdentitySha256",
        "sizeBytes",
        "logicalSectorBytes",
        "modelSha256",
        "serialSha256",
        "endpoint",
        "transportCapability",
        "installerHostPublicKey",
        "installerHostKeyFingerprint",
        "finalHostKeyFingerprint",
        "installKeyPublicKey",
        "installKeyFingerprint",
        "permanentLoginKeyFingerprint",
        "installAuthorizerPrincipal",
        "issuedAt",
        "expiresAt",
        "nonce",
        "subactions",
    }
    row = exact_keys(value, expected, "manifest")
    if row["schemaVersion"] != 1:
        raise ContractError("manifest-version")
    require_transaction(row["transactionId"])
    require_host(row["hostId"])
    if not isinstance(row["target"], str) or not row["target"].startswith("nixosConfigurations."):
        raise ContractError("manifest-target")
    if not isinstance(row["sourceGitCommit"], str) or re.fullmatch(r"[0-9a-f]{40}", row["sourceGitCommit"]) is None:
        raise ContractError("manifest-source-commit")
    for field in (
        "flakeLockSha256",
        "declarationDigest",
        "installerDeviceBindingSha256",
        "installerTopLevelNarHash",
        "installerClosureDigest",
        "manifestRequestSha256",
        "recoveryTopLevelNarHash",
        "recoveryClosureDigest",
        "candidateTopLevelNarHash",
        "candidateClosureDigest",
        "isoSha256",
        "payloadManifestSha256",
        "provisioningPayloadSha256",
        "diskIdentitySha256",
        "modelSha256",
        "serialSha256",
    ):
        field_digest = require_sha(row[field], f"manifest-{field}")
        if set(field_digest) == {"0"}:
            raise ContractError(f"manifest-{field}-zero")
    installer_boot_id = row["installerBootId"]
    if not isinstance(installer_boot_id, str) or BOOT_ID.fullmatch(installer_boot_id) is None:
        raise ContractError("manifest-boot")
    system_paths: list[str] = []
    for field in ("installerSystemPath", "recoverySystemPath", "candidateSystemPath"):
        system_path = row[field]
        if not isinstance(system_path, str) or not system_path.startswith("/nix/store/"):
            raise ContractError("manifest-system-path")
        system_paths.append(system_path)
    iso_size = row["isoArtifactSizeBytes"]
    if not isinstance(iso_size, int) or iso_size <= 0 or iso_size % 2048:
        raise ContractError("manifest-iso-size")
    require_disk_basename(row["diskById"])
    logical_sector_bytes = row["logicalSectorBytes"]
    size_bytes = row["sizeBytes"]
    if logical_sector_bytes not in (512, 4096) or not isinstance(size_bytes, int) or size_bytes <= 0:
        raise ContractError("manifest-disk-geometry")
    endpoint = row["endpoint"]
    if not isinstance(endpoint, dict) or set(endpoint) != {"address", "port"}:
        raise ContractError("manifest-endpoint")
    canonical_endpoint(endpoint["address"], endpoint["port"])
    if row["transportCapability"] not in ("network.ethernet", "network.usb-ethernet", "network.usb-tether"):
        raise ContractError("manifest-transport")
    for field in ("installerHostPublicKey", "installKeyPublicKey"):
        public_key = row[field]
        if not isinstance(public_key, str) or re.fullmatch(r"ssh-ed25519 [A-Za-z0-9+/]+={0,2}", public_key) is None:
            raise ContractError("manifest-public-key")
    release_fingerprint = row["releaseSignerFingerprint"]
    if not isinstance(release_fingerprint, str) or re.fullmatch(r"SHA256:[A-Za-z0-9+/]+={0,2}", release_fingerprint) is None:
        raise ContractError("manifest-release-fingerprint")
    fingerprints: list[str] = []
    for field in ("installerHostKeyFingerprint", "finalHostKeyFingerprint", "installKeyFingerprint", "permanentLoginKeyFingerprint"):
        fingerprint = row[field]
        if not isinstance(fingerprint, str) or re.fullmatch(r"SHA256:[A-Za-z0-9+/]+={0,2}", fingerprint) is None:
            raise ContractError("manifest-fingerprint")
        fingerprints.append(fingerprint)
    if len(set(system_paths)) != 3:
        raise ContractError("manifest-system-path-collision")
    if len(set(fingerprints)) != 4:
        raise ContractError("manifest-fingerprint-collision")
    if not isinstance(row["installAuthorizerPrincipal"], str) or not re.fullmatch(r"[A-Za-z0-9._-]+", row["installAuthorizerPrincipal"]):
        raise ContractError("manifest-principal")
    times: list[str] = []
    for field in ("issuedAt", "expiresAt"):
        timestamp = row[field]
        if not isinstance(timestamp, str) or not re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z", timestamp):
            raise ContractError("manifest-time")
        times.append(timestamp)
    if times[1] <= times[0]:
        raise ContractError("manifest-window")
    if not isinstance(row["nonce"], str) or re.fullmatch(r"[0-9a-f]{48}", row["nonce"]) is None:
        raise ContractError("manifest-nonce")
    if row["subactions"] != ["erase-install", "provision", "reboot-recovery"]:
        raise ContractError("manifest-subactions")
