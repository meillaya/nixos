# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
# ─── How to run ───
# Imported by the Task-15 hardware collector and intake validator.
from __future__ import annotations

import hashlib
import math
import re
from typing import Final

from scripts.hardware.enrollment import validate_x86_enrollment
from scripts.hardware.operational import is_operationally_disabled
from scripts.hardware.platform_expectations import validate_platform_expectations
from scripts.hardware.primitives import ContractError, JsonObject, _integer, _keys, _string
from scripts.support.canonical_json import JsonValue, encode
from scripts.hardware.trust import validate_trust
_SHA256: Final = re.compile(r"^[0-9a-f]{64}$")
_SAFE_ID: Final = re.compile(r"^[a-z][a-z0-9-]{0,63}$")
_SAFE_DISK: Final = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:+-]{0,254}$")
_DISK_PARTITION: Final = re.compile(r".*-part[0-9]+$")
_PCI_CLASS: Final = re.compile(r"^[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}$")
_DRIVER: Final = re.compile(r"^[A-Za-z0-9_-]{1,64}$")
_AGE: Final = re.compile(r"^age1[023456789acdefghjklmnpqrstuvwxyz]{58}$")
_TIME_ZONE: Final = re.compile(r"^[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)+$")
_LOCALE: Final = re.compile(r"^[A-Za-z][A-Za-z0-9_@.-]{1,63}$")
_KEYMAP: Final = re.compile(r"^[A-Za-z0-9_-]{1,32}$")
_ROUTES: Final = {"remembrance": ("nixosConfigurations.remembrance", "x86_64-linux", "workstation"), "antagony": ("nixosConfigurations.antagony", "x86_64-linux", "workstation"), "entropy": ("darwinConfigurations.entropy", "aarch64-darwin", "workstation")}


def _object(value: JsonValue, label: str) -> JsonObject:
    if not isinstance(value, dict):
        raise ContractError(f"{label} object")
    return value


def _sha(value: JsonValue, label: str) -> str:
    return _string(value, _SHA256, label)


def _capability(value: JsonValue, label: str) -> JsonObject:
    if not isinstance(value, dict):
        raise ContractError(f"{label} object")
    state = value.get("state")
    if state == "present":
        return _keys(value, {"state"}, label)
    if state == "absent":
        row = _keys(value, {"state", "reason"}, label)
        if row["reason"] not in {"not-equipped", "unsupported", "deferred"}:
            raise ContractError(f"{label} absence")
        return row
    raise ContractError(f"{label} state")


def _firmware_expectation(value: JsonValue, pci_class: str, label: str) -> JsonObject:
    if not isinstance(value, dict):
        raise ContractError(f"{label} object")
    state = value.get("state")
    if state == "driver-bound-no-load-failure":
        return _keys(value, {"state"}, label)
    if state == "not-required":
        row = _keys(value, {"state", "reason"}, label)
        if pci_class not in {"06:00:00", "06:04:00"} or row["reason"] != "device-has-no-loadable-firmware":
            raise ContractError(f"{label} allowlist")
        return row
    raise ContractError(f"{label} state")


def _firmware_row(value: JsonValue, label: str) -> JsonObject:
    row = _keys(value, {"logicalId", "pciClass", "expectedDriver", "firmwareExpectation"}, label)
    _string(row["logicalId"], re.compile(r"^[a-z][a-z0-9-]{0,63}$"), f"{label}.logicalId")
    pci = _string(row["pciClass"], _PCI_CLASS, f"{label}.pciClass")
    _string(row["expectedDriver"], _DRIVER, f"{label}.expectedDriver")
    _firmware_expectation(row["firmwareExpectation"], pci, f"{label}.firmwareExpectation")
    return row


def _network_row(value: JsonValue, label: str) -> JsonObject:
    row = _keys(value, {"capability", "controllerClass", "expectedDriver", "firmwareExpectation"}, label)
    capability = row["capability"]
    if capability not in {"network.ethernet", "network.usb-ethernet", "network.usb-tether", "network.wifi"}:
        raise ContractError(f"{label}.capability")
    pci = _string(row["controllerClass"], _PCI_CLASS, f"{label}.controllerClass")
    _string(row["expectedDriver"], _DRIVER, f"{label}.expectedDriver")
    _firmware_expectation(row["firmwareExpectation"], pci, f"{label}.firmwareExpectation")
    return row


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



def validate_declaration(value: JsonValue) -> JsonObject:
    """Parse and validate a closed machine declaration projection."""
    fields = {"hostId", "target", "system", "role", "identity", "location", "display", "boot", "storage", "publicTrust", "secretTrust", "cpuVendor", "firmware", "kernel", "gpu", "network", "devices", "capabilities", "ddcConnectors", "remoteInstall", "platformExpectations"}
    top = _keys(value, fields, "declaration")
    host = _string(top["hostId"], _SAFE_ID, "hostId")
    route = _ROUTES.get(host)
    if route is None or (top["target"], top["system"], top["role"]) != route:
        raise ContractError("routing")
    identity = _keys(top["identity"], {"name", "home", "uid", "gid"}, "identity")
    _string(identity["name"], re.compile(r"^[a-z_][a-z0-9_-]{0,31}$"), "identity.name")
    _string(identity["home"], re.compile(r"^/[^\x00-\x1f]+$"), "identity.home")
    uid = _integer(identity["uid"], "identity.uid")
    gid = _integer(identity["gid"], "identity.gid")
    if uid > 2_147_483_647 or gid > 2_147_483_647:
        raise ContractError("identity id ceiling")
    expected_home = f"/Users/{identity['name']}" if top["system"] == "aarch64-darwin" else f"/home/{identity['name']}"
    if identity["home"] != expected_home:
        raise ContractError("identity home platform")
    location = _keys(top["location"], {"timeZone", "locale", "keymap", "xkb"}, "location")
    _string(location["timeZone"], _TIME_ZONE, "location.timeZone")
    _string(location["locale"], _LOCALE, "location.locale")
    _string(location["keymap"], _KEYMAP, "location.keymap")
    _string(location["xkb"], _KEYMAP, "location.xkb")
    display = _keys(top["display"], {"scale"}, "display")
    scale = _keys(display["scale"], {"numerator", "denominator"}, "display.scale")
    numerator = _integer(scale["numerator"], "display.scale.numerator", positive=True)
    denominator = _integer(scale["denominator"], "display.scale.denominator", positive=True)
    if math.gcd(numerator, denominator) != 1 or numerator < denominator or numerator > 4 * denominator:
        raise ContractError("display scale")
    boot = top["boot"]
    if not isinstance(boot, dict):
        raise ContractError("boot object")
    if boot.get("state") == "uefi":
        _keys(boot, {"state", "secureBoot", "configurationLimit"}, "boot")
        if boot["secureBoot"] is not False or boot["configurationLimit"] != 10:
            raise ContractError("boot policy")
    elif boot.get("state") != "disabled" or set(boot) != {"state"}:
        raise ContractError("boot state")
    storage = top["storage"]
    if not isinstance(storage, dict):
        raise ContractError("storage object")
    if storage.get("profile") == "single-gpt-btrfs":
        _keys(storage, {"profile", "diskById", "expected"}, "storage")
        disk_by_id = _string(storage["diskById"], _SAFE_DISK, "storage.diskById")
        if _DISK_PARTITION.fullmatch(disk_by_id):
            raise ContractError("storage partition path")
        expected = _keys(storage["expected"], {"sizeBytes", "logicalSectorBytes", "modelSha256", "serialSha256"}, "storage.expected")
        _integer(expected["sizeBytes"], "storage.expected.sizeBytes", positive=True)
        if expected["logicalSectorBytes"] not in {512, 4096}:
            raise ContractError("storage sector")
        _sha(expected["modelSha256"], "storage.modelSha256")
        _sha(expected["serialSha256"], "storage.serialSha256")
    elif storage != {"profile": "none"}:
        raise ContractError("storage profile")
    boot_obj = _object(boot, "boot")
    storage_obj = _object(storage, "storage")
    validate_trust(top["publicTrust"], top["secretTrust"])
    vendor = top["cpuVendor"]
    if vendor not in {"pending", "GenuineIntel", "AuthenticAMD", "Apple"}:
        raise ContractError("cpu vendor")
    policies = {"firmware": {"disabled", "redistributable", "apple"}, "kernel": {"disabled", "nixpkgs-default"}, "gpu": {"disabled", "cpu-only", "generic-vulkan", "apple-metal"}, "network": {"disabled", "networkmanager", "native-darwin"}}
    for key, allowed in policies.items():
        if top[key] not in allowed:
            raise ContractError(f"{key} policy")
    devices = top["devices"]
    capabilities = top["capabilities"]
    if isinstance(devices, dict) and devices.get("state") == "enrolled":
        _validate_devices(devices)
    elif devices != {"state": "disabled"}:
        raise ContractError("devices state")
    if isinstance(capabilities, dict) and capabilities.get("state") == "enrolled":
        _validate_capabilities(capabilities)
    elif capabilities != {"state": "disabled"}:
        raise ContractError("capabilities state")
    _validate_ddc(top["ddcConnectors"])
    if not isinstance(top["remoteInstall"], bool):
        raise ContractError("remoteInstall boolean")
    platform_expectations = validate_platform_expectations(top["platformExpectations"])
    if platform_expectations["kind"] != ("darwin" if top["system"] == "aarch64-darwin" else "none"):
        raise ContractError("platform/system correspondence")
    if host in {"remembrance", "antagony"} and vendor == "pending":
        if boot != {"state": "disabled"} or storage != {"profile": "none"} or top["publicTrust"] != {"state": "disabled"} or top["secretTrust"] != {"state": "disabled"} or top["devices"] != {"state": "disabled"} or top["capabilities"] != {"state": "disabled"} or top["ddcConnectors"] != [] or top["remoteInstall"] is not False or top["firmware"] != "disabled" or top["kernel"] != "disabled" or top["gpu"] != "disabled" or top["network"] != "disabled":
            raise ContractError("x86 pending closure")
    elif host in {"remembrance", "antagony"}:
        if vendor not in {"GenuineIntel", "AuthenticAMD"}:
            raise ContractError("x86 cpu vendor")
        devices_obj = _object(devices, "devices")
        capabilities_obj = _object(capabilities, "capabilities")
        public_obj = _object(top["publicTrust"], "publicTrust")
        secret_obj = _object(top["secretTrust"], "secretTrust")
        if devices_obj.get("state") != "enrolled" or capabilities_obj.get("state") != "enrolled":
            raise ContractError("x86 capability enrollment")
        network_rows = _sorted_unique(devices_obj["network"], "capability", "network")
        validate_x86_enrollment(top, boot_obj, storage_obj, public_obj, secret_obj, platform_expectations, devices_obj, capabilities_obj, network_rows)
    elif host == "entropy":
        if vendor != "Apple" or top["firmware"] != "apple" or top["kernel"] != "disabled" or top["gpu"] != "apple-metal" or top["network"] != "native-darwin" or platform_expectations["kind"] != "darwin" or not is_operationally_disabled(top):
            raise ContractError("entropy closure")
    return top


def _validate_devices(devices: JsonObject) -> None:
    _keys(devices, {"state", "firmware", "network", "gpu", "powerDaemon"}, "devices")
    firmware = _sorted_unique(devices["firmware"], "logicalId", "firmware")
    if not firmware:
        raise ContractError("firmware inventory empty")
    for row in firmware:
        _firmware_row(row, "firmware")
    network = _sorted_unique(devices["network"], "capability", "network")
    for row in network:
        _network_row(row, "network")
    gpu = devices["gpu"]
    if gpu is not None:
        row = _keys(gpu, {"expectedDriver", "expectedRendererDigest"}, "gpu")
        _string(row["expectedDriver"], _DRIVER, "gpu.expectedDriver")
        _sha(row["expectedRendererDigest"], "gpu.expectedRendererDigest")
    if devices["powerDaemon"] not in {None, "power-profiles-daemon"}:
        raise ContractError("power daemon")


def _validate_capabilities(capabilities: JsonObject) -> None:
    _keys(capabilities, {"state", "values"}, "capabilities")
    capability_keys = {"install.direct", "install.remote", "reboot", "rollback", "firmware", "microcode", "network.ethernet", "network.usb-ethernet", "network.usb-tether", "network.wifi", "recovery.local-console", "gpu", "audio", "bluetooth", "power", "suspend", "ddc", "session", "portal-obs", "theme-kitty"}
    values = _keys(capabilities["values"], capability_keys, "capabilities.values")
    for key, value in values.items():
        _capability(value, f"capabilities.values.{key}")


def _validate_ddc(connectors: JsonValue) -> None:
    rows = _sorted_unique(connectors, "connector", "ddcConnectors")
    for row in rows:
        _keys(row, {"connector", "i2cLocatorDigest", "sysfsConnectorDigest"}, "ddc connector")
        _string(row["connector"], re.compile(r"^[A-Za-z]+-[A-Za-z0-9-]+$"), "ddc.connector")
        _sha(row["i2cLocatorDigest"], "ddc.i2cLocatorDigest")
        _sha(row["sysfsConnectorDigest"], "ddc.sysfsConnectorDigest")


def declaration_digest(value: JsonValue) -> str:
    """Return the digest bound to canonical declaration bytes."""
    validated = validate_declaration(value)
    return hashlib.sha256(encode(validated)).hexdigest()
