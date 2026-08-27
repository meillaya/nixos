# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
# ─── How to run ───
# Imported by hardware/auto_enroll.py; not meant to be invoked directly.
#
# Probes the REAL hardware of the machine it runs on and produces the typed
# "attended fixture" that `scripts/hardware/collector.py::collect_fixture`
# sanitizes into a canonical machine declaration.
#
# It reads only system facts (sysfs, lspci, /proc) and never opens a block
# device for writing and never emits a raw hardware identifier. Serial numbers,
# MACs, and UUIDs are hashed before they ever enter the fixture, so the
# collector's `_walk_forbidden` gate is satisfied.
from __future__ import annotations

import hashlib
import os
import re
import subprocess
from pathlib import Path
from typing import Final

from scripts.hardware.primitives import ContractError, JsonObject

# Capability keys must exactly match the collector's CAPABILITY_KEYS.
_CAPABILITY_KEYS: Final = (
    "install.direct",
    "install.remote",
    "reboot",
    "rollback",
    "firmware",
    "microcode",
    "network.ethernet",
    "network.usb-ethernet",
    "network.usb-tether",
    "network.wifi",
    "recovery.local-console",
    "gpu",
    "audio",
    "bluetooth",
    "power",
    "suspend",
    "ddc",
    "session",
    "portal-obs",
    "theme-kitty",
)
_NETWORK_KEYS: Final = ("network.ethernet", "network.usb-ethernet", "network.usb-tether", "network.wifi")
_ALWAYS_REQUIRED: Final = (
    "install.direct",
    "reboot",
    "rollback",
    "firmware",
    "microcode",
    "recovery.local-console",
    "session",
    "portal-obs",
    "theme-kitty",
)
# PCI classes that legitimately carry no loadable firmware (host bridges).
_NOT_REQUIRED_PCI_CLASSES: Final = {"06:00:00", "06:04:00"}
# 4-digit lspci base classes (class:subclass, prog-if normalized to 00).
_CLASS_ETHERNET: Final = "02:00:00"
_CLASS_WIFI: Final = "02:80:00"
_CLASS_GPU: Final = "03:00:00"


def _run(argv: list[str]) -> str:
    try:
        return subprocess.run(argv, capture_output=True, text=True, check=False).stdout
    except OSError as error:  # pragma: no cover - missing tool on target
        raise ContractError(f"probe command unavailable: {argv[0]}") from error


def _sha256(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def _cpu_vendor() -> str:
    for line in Path("/proc/cpuinfo").read_text().splitlines():
        if line.startswith("vendor_id"):
            vendor = line.split(":", 1)[1].strip()
            if vendor in {"GenuineIntel", "AuthenticAMD"}:
                return vendor
    raise ContractError("probe: unsupported or unknown CPU vendor")


def _secure_boot() -> bool:
    # SecureBoot variable: last byte of the efivar payload is 1 when enabled.
    for var in Path("/sys/firmware/efi/efivars").glob("SecureBoot-*"):
        try:
            data = var.read_bytes()
            return data[-1] == 1
        except (OSError, IndexError):
            return False
    return False


def _storage_expected(disk_by_id: str) -> JsonObject:
    # Resolve the by-id basename to its block device, then read sysfs facts.
    link = Path("/dev/disk/by-id") / disk_by_id
    if not link.is_symlink():
        raise ContractError(f"probe: disk by-id not found: {disk_by_id}")
    device = link.resolve()
    name = device.name
    sys_block = Path("/sys/block") / name
    if not sys_block.is_dir():
        raise ContractError(f"probe: block device missing: {name}")
    sectors = int((sys_block / "size").read_text().strip())
    logical_sector = int((sys_block / "queue" / "logical_block_size").read_text().strip())
    model = (sys_block / "device" / "model").read_text().strip()
    serial = (sys_block / "device" / "serial").read_text().strip()
    return {
        "sizeBytes": sectors * logical_sector,
        "logicalSectorBytes": logical_sector,
        "modelSha256": _sha256(model),
        "serialSha256": _sha256(serial),
    }


def _is_candidate_block(name: str) -> bool:
    # Whole internal block devices only. Skip loop/ram/zram/dm/sr/fd/md and any
    # device attached over USB — that covers the installer media the ISO booted
    # from and external USB drives, leaving internal NVMe/SATA/SCSI as targets.
    if name.startswith(("loop", "ram", "zram", "dm-", "sr", "fd", "md")):
        return False
    sys_block = Path("/sys/block") / name
    if not sys_block.is_dir():
        return False
    device_path = os.path.realpath(sys_block / "device")
    if "/usb" in device_path:
        return False
    return True


def _whole_device_ids() -> dict[str, tuple[str, int]]:
    # Maps resolved block-device name -> (canonical by-id basename, sizeBytes).
    candidates: dict[str, tuple[str, int]] = {}
    by_id = Path("/dev/disk/by-id")
    if not by_id.is_dir():
        return candidates
    for entry in by_id.iterdir():
        name = entry.name
        if name.endswith(("-part", "-part1")) or re.search(r"-part\d+$", name):
            continue
        # Skip synthetic aliases (wwn-/eui-/... duplicates of the same device);
        # keep the vendor/model names which are stable whole-device basenames.
        if re.search(r"^(wwn-|eui-|nvme-eui-|scsi-|pci-|usb-|ata-|nvme-)", name) is None:
            continue
        if not entry.is_symlink():
            continue
        device = entry.resolve()
        dev_name = device.name
        if dev_name not in candidates and _is_candidate_block(dev_name):
            sectors = int((Path("/sys/block") / dev_name / "size").read_text().strip())
            logical = int((Path("/sys/block") / dev_name / "queue" / "logical_block_size").read_text().strip())
            candidates[dev_name] = (name, sectors * logical)
    return candidates


def discover_target_disk(preferred: str | None = None) -> str:
    """Auto-select the target whole-device disk basename.

    If a preferred basename is given and it names a present candidate, it wins
    (safe deterministic reinstall of the same disk). Otherwise the largest
    candidate is chosen; ties break lexicographically.
    """
    candidates = _whole_device_ids()
    if not candidates:
        raise ContractError("probe: no candidate target disk found")
    present = {name for name, _ in candidates.values()}
    if preferred and preferred in present:
        return preferred
    best = max(candidates.values(), key=lambda item: (item[1], item[0]))
    return best[0]


def _pci_devices() -> list[tuple[str, str, str]]:
    # Returns (pciAddress, classCode, description). lspci emits 4-digit base
    # classes ("0200") which are normalized to the 6-digit "aa:bb:00" form the
    # machine schema uses. Field separation varies by pciutils build, so the
    # class is extracted from the first bracketed 4-hex group rather than by
    # splitting on a fixed separator.
    out = _run(["lspci", "-nnmm"])
    devices: list[tuple[str, str, str]] = []
    for line in out.splitlines():
        fields = line.split()
        if not fields:
            continue
        address = fields[0]
        class_match = re.search(r"\[([0-9a-f]{4})\]", line)
        if not class_match:
            continue
        base = class_match.group(1)
        normalized = f"{base[0:2]}:{base[2:4]}:00"
        devices.append((address, normalized, line))
    return devices


def _driver_for(address: str) -> str | None:
    # lspci addresses (e.g. "26:00.0") need the "0000:" domain prefix to map to
    # the /sys/bus/pci/devices/<address> path.
    sysfs_addr = address if address.startswith("0000:") else f"0000:{address}"
    link = Path("/sys/bus/pci/devices") / sysfs_addr / "driver"
    if link.is_symlink():
        return Path(link.resolve()).name
    return None


def _gpu_renderer_digest() -> str | None:
    out = _run(["glxinfo", "-B"])
    for line in out.splitlines():
        if "OpenGL renderer string:" in line:
            return _sha256(line.split(":", 1)[1].strip())
    return None


def _network_rows_and_caps(pci: list[tuple[str, str, str]]) -> tuple[list[JsonObject], list[str]]:
    ethernet: list[tuple[str, str, str]] = []
    wifi: list[tuple[str, str, str]] = []
    for address, pci_class, _ in pci:
        driver = _driver_for(address) or "unknown"
        if pci_class == _CLASS_ETHERNET and driver in {"igb", "r8169", "e1000e", "ixgbe", "igc", "igbvf"}:
            ethernet.append((address, pci_class, driver))
        elif pci_class == _CLASS_WIFI and driver in {"iwlwifi", "iwlwifi-pcie"}:
            wifi.append((address, pci_class, driver))

    rows: list[JsonObject] = []
    caps: list[str] = []

    # Only one network.ethernet row is allowed; if more than one controller is
    # present, pick the one with carrier (active link), else the first.
    if ethernet:
        selected = _pick_active_ethernet(ethernet)
        address, pci_class, driver = selected
        rows.append(
            {
                "capability": "network.ethernet",
                "controllerClass": pci_class,
                "expectedDriver": driver,
                "firmwareExpectation": {"state": "driver-bound-no-load-failure"},
            }
        )
        caps.append("network.ethernet")

    for address, pci_class, driver in wifi:
        rows.append(
            {
                "capability": "network.wifi",
                "controllerClass": pci_class,
                "expectedDriver": driver,
                "firmwareExpectation": {"state": "driver-bound-no-load-failure"},
            }
        )
        caps.append("network.wifi")
        break

    rows.sort(key=lambda r: r["capability"])
    caps.sort()
    return rows, caps


def _pick_active_ethernet(controllers: list[tuple[str, str, str]]) -> tuple[str, str, str]:
    for address, _, driver in controllers:
        iface = _interface_for(address)
        if iface is None:
            continue
        carrier = Path(f"/sys/class/net/{iface}/carrier")
        if carrier.is_file() and carrier.read_text().strip() == "1":
            return address, _CLASS_ETHERNET, driver
    return controllers[0]


def _interface_for(address: str) -> str | None:
    sysfs_addr = address if address.startswith("0000:") else f"0000:{address}"
    net_dir = Path("/sys/bus/pci/devices") / sysfs_addr / "net"
    if not net_dir.is_dir():
        return None
    interfaces = list(net_dir.iterdir())
    return interfaces[0].name if interfaces else None


def _capability_values(
    network_caps: list[str],
    audio: bool,
    bluetooth: bool,
    gpu_present: bool,
    power: bool,
    ddc_present: bool,
    remote: bool,
) -> JsonObject:
    present = {
        "install.direct",
        "reboot",
        "rollback",
        "firmware",
        "microcode",
        "recovery.local-console",
        "session",
        "portal-obs",
        "theme-kitty",
    }
    if audio:
        present.add("audio")
    if bluetooth:
        present.add("bluetooth")
    if gpu_present:
        present.add("gpu")
    if power:
        present.add("power")
    if ddc_present:
        present.add("ddc")
    present.update(network_caps)
    if remote:
        present.add("install.remote")
    values: dict[str, JsonObject] = {}
    for key in _CAPABILITY_KEYS:
        if key in present:
            values[key] = {"state": "present"}
        elif key == "install.remote":
            values[key] = {"state": "absent", "reason": "not-equipped"}
        else:
            values[key] = {"state": "absent", "reason": "not-equipped"}
    return {"state": "enrolled", "values": values}


def _has_pci_class(pci: list[tuple[str, str, str]], pci_class: str) -> bool:
    return any(cls == pci_class for _, cls, _ in pci)


def _has_audio() -> bool:
    return len(list(Path("/proc/asound").glob("card*"))) > 0


def _has_bluetooth() -> bool:
    return any(Path("/sys/class/bluetooth").iterdir()) if Path("/sys/class/bluetooth").is_dir() else False


def _has_ddc() -> bool:
    return any(p.name.startswith("i2c-") for p in Path("/sys/class/i2c-adapter").iterdir()) if Path(
        "/sys/class/i2c-adapter"
    ).is_dir() else False


def _power_daemon() -> str | None:
    for unit in ("power-profiles-daemon.service",):
        if (Path("/run/systemd/system") / unit).exists():
            return "power-profiles-daemon"
    return None


def probe_fixture(base: JsonObject, trust: JsonObject, disk_by_id: str | None = None) -> JsonObject:
    """Build the typed attended fixture from the real hardware of this machine.

    `base` is the current build-time machine declaration (provides hostId,
    target, system, role, identity, location, display). `trust` is the
    operator-supplied public/secret trust fixture. `disk_by_id` is an optional
    whole-device basename; when omitted the target disk is auto-discovered,
    preferring the disk already bound in `base` when it is still present.
    """
    if disk_by_id is None:
        preferred = base.get("storage", {}).get("diskById")
        disk_by_id = discover_target_disk(preferred if isinstance(preferred, str) else None)
    vendor = _cpu_vendor()
    secure_boot = _secure_boot()
    storage_expected = _storage_expected(disk_by_id)

    pci = _pci_devices()
    network_rows, network_caps = _network_rows_and_caps(pci)

    gpu_present = _has_pci_class(pci, _CLASS_GPU)
    gpu = None
    if gpu_present:
        driver = "amdgpu"
        for address, pci_class, _ in pci:
            if pci_class == _CLASS_GPU:
                driver = _driver_for(address) or "amdgpu"
                break
        renderer = _gpu_renderer_digest()
        if renderer is None:
            raise ContractError("probe: GPU present but renderer digest unavailable (need glxinfo)")
        gpu = {"expectedDriver": driver, "expectedRendererDigest": renderer}

    audio = _has_audio()
    bluetooth = _has_bluetooth()
    ddc_present = _has_ddc()
    power = _power_daemon() == "power-profiles-daemon"
    remote = False

    # Firmware inventory: network controllers + GPU + host bridge (+ NVMe).
    firmware: list[JsonObject] = []
    for row in network_rows:
        logical_id = row["capability"].split(".", 1)[1]
        firmware.append(
            {
                "logicalId": logical_id,
                "pciClass": row["controllerClass"],
                "expectedDriver": row["expectedDriver"],
                "firmwareExpectation": {"state": "driver-bound-no-load-failure"},
            }
        )
    if gpu_present:
        firmware.append(
            {
                "logicalId": "display",
                "pciClass": _CLASS_GPU,
                "expectedDriver": gpu["expectedDriver"],
                "firmwareExpectation": {"state": "driver-bound-no-load-failure"},
            }
        )
    for address, pci_class, _ in pci:
        if pci_class in _NOT_REQUIRED_PCI_CLASSES:
            firmware.append(
                {
                    "logicalId": "host-bridge",
                    "pciClass": pci_class,
                    "expectedDriver": "pcieport",
                    "firmwareExpectation": {"reason": "device-has-no-loadable-firmware", "state": "not-required"},
                }
            )
            break
    if not firmware:
        raise ContractError("probe: firmware inventory empty")
    firmware.sort(key=lambda row: row["logicalId"])

    capabilities = _capability_values(network_caps, audio, bluetooth, gpu_present, power, ddc_present, remote)

    return {
        "schemaVersion": 1,
        "hostId": base["hostId"],
        "target": base["target"],
        "system": base["system"],
        "role": base["role"],
        "identity": base["identity"],
        "location": base["location"],
        "display": base["display"],
        "cpu": {"vendor": vendor},
        "uefi": {"secureBoot": secure_boot, "configurationLimit": 10},
        "storage": {
            "diskById": disk_by_id,
            "expected": storage_expected,
            "descriptor": {"diskById": disk_by_id, "expected": storage_expected},
        },
        "trust": trust,
        "firmware": firmware,
        "gpu": gpu,
        "network": {
            "policy": "networkmanager",
            "capabilities": network_caps,
            "rows": network_rows,
            "remoteInstall": remote,
            "fallback": {"localConsole": True, "reconnect": True},
        },
        "powerDaemon": _power_daemon(),
        "devices": {
            "audio": {"state": "present" if audio else "absent", **({} if audio else {"reason": "not-equipped"})},
            "bluetooth": {
                "state": "present" if bluetooth else "absent",
                **({} if bluetooth else {"reason": "not-equipped"}),
            },
        },
        "capabilities": capabilities,
        "ddcConnectors": [],
        "platformExpectations": base.get("platformExpectations", {"kind": "none"}),
    }
