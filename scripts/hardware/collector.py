# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
# ─── How to run ───
# python3 -B -I bin/nix-config-hardware-collector --fixture FIXTURE.json
from __future__ import annotations

import base64
import hashlib
import re
from pathlib import Path
from typing import Final, assert_never

from scripts.support.canonical_json import CanonicalJsonError, JsonValue, read_regular, require_canonical
from scripts.hardware.contracts import ContractError, JsonObject, _integer, _keys, _sha, _string, _validate_devices, _validate_ddc, validate_declaration

CAPABILITY_KEYS: Final = ("install.direct", "install.remote", "reboot", "rollback", "firmware", "microcode", "network.ethernet", "network.usb-ethernet", "network.usb-tether", "network.wifi", "recovery.local-console", "gpu", "audio", "bluetooth", "power", "suspend", "ddc", "session", "portal-obs", "theme-kitty")
NETWORK_KEYS: Final = ("network.ethernet", "network.usb-ethernet", "network.usb-tether", "network.wifi")
ROUTES: Final = {
    "remembrance": ("nixosConfigurations.remembrance", "x86_64-linux", "workstation"),
    "antagony": ("nixosConfigurations.antagony", "x86_64-linux", "workstation"),
}
_FORBIDDEN: Final = {"renderer", "rawRenderer", "expectedRenderer", "renderedText", "pciAddress", "slot", "mac", "macAddress", "ssid", "ip", "ipv4", "ipv6", "serial", "serialNumber", "dmiUuid", "dmiAddress", "uuid", "address", "busAddress", "pciSlot", "interface", "ifname", "facter", "freeText", "privateKey"}


def _fingerprint(key: JsonValue, label: str) -> str:
    value = _string(key, re.compile(r"^ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA[A-Za-z0-9+/]{32,}$"), label)
    parts = value.split(" ")
    try:
        payload = base64.b64decode(parts[1], validate=True)
    except (ValueError, IndexError) as error:
        raise ContractError(f"{label} encoding") from error
    if len(payload) != 51 or not payload.startswith(b"\x00\x00\x00\x0bssh-ed25519\x00\x00\x00\x20"):
        raise ContractError(f"{label} key blob")
    digest = base64.b64encode(hashlib.sha256(payload).digest()).decode("ascii").rstrip("=")
    return f"SHA256:{digest}"


def _walk_forbidden(value: JsonValue) -> None:
    match value:
        case dict() as mapping:
            if set(mapping) & _FORBIDDEN:
                raise ContractError("raw hardware identifier")
            for child in mapping.values():
                _walk_forbidden(child)
        case list() as rows:
            for child in rows:
                _walk_forbidden(child)
        case None | bool() | int() | float() | str():
            return
        case unreachable:
            assert_never(unreachable)


def _capability_values(source: JsonObject, network_caps: list[str], remote: bool) -> JsonObject:
    raw = source["capabilities"]
    if not isinstance(raw, dict):
        raise ContractError("capabilities object")
    if raw.get("state") != "enrolled":
        raise ContractError("capability state")
    values = raw.get("values")
    if not isinstance(values, dict) or set(values) != set(CAPABILITY_KEYS):
        raise ContractError("capability key set")
    result: dict[str, JsonValue] = {}
    for key in CAPABILITY_KEYS:
        value = values[key]
        if not isinstance(value, dict):
            raise ContractError(f"capability {key}")
        state = value.get("state")
        if state not in {"present", "absent"}:
            raise ContractError(f"capability {key} state")
        if state == "present" and set(value) != {"state"}:
            raise ContractError(f"capability {key} fields")
        if state == "absent" and (set(value) != {"state", "reason"} or value["reason"] not in {"not-equipped", "unsupported", "deferred"}):
            raise ContractError(f"capability {key} absence")
        result[key] = value
    for key in NETWORK_KEYS:
        expected = key in network_caps
        capability = result[key]
        if not isinstance(capability, dict):
            raise ContractError(f"network capability {key}")
        if (capability.get("state") == "present") != expected:
            raise ContractError(f"network capability {key}")
    remote_capability = result["install.remote"]
    if not isinstance(remote_capability, dict):
        raise ContractError("remote capability")
    if (remote_capability.get("state") == "present") != remote:
        raise ContractError("remote capability")
    return {"state": "enrolled", "values": result}


def collect_fixture(source: JsonValue) -> JsonObject:
    """Convert an attended, typed fixture into a sanitized declaration."""
    _walk_forbidden(source)
    fields = {"schemaVersion", "hostId", "target", "system", "role", "identity", "location", "display", "cpu", "uefi", "storage", "trust", "firmware", "gpu", "network", "powerDaemon", "devices", "capabilities", "ddcConnectors", "platformExpectations"}
    src = _keys(source, fields, "collector input")
    if src["schemaVersion"] != 1:
        raise ContractError("schema version")
    host = _string(src["hostId"], re.compile(r"^[a-z][a-z0-9-]{0,63}$"), "hostId")
    route = ROUTES.get(host)
    if route is None or tuple(src[name] for name in ("target", "system", "role")) != route:
        raise ContractError("host route")
    cpu = _keys(src["cpu"], {"vendor"}, "cpu")
    vendor = cpu["vendor"]
    if vendor not in {"GenuineIntel", "AuthenticAMD"}:
        raise ContractError("pending or unknown cpu vendor")
    uefi = _keys(src["uefi"], {"secureBoot", "configurationLimit"}, "uefi")
    if uefi["secureBoot"] is not False or uefi["configurationLimit"] != 10:
        raise ContractError("UEFI policy")
    storage = _keys(src["storage"], {"diskById", "expected", "descriptor"}, "storage")
    disk_by_id = _string(storage["diskById"], re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:+-]{0,254}$"), "storage.diskById")
    if re.fullmatch(r".*-part[0-9]+", disk_by_id):
        raise ContractError("storage partition path")
    expected = _keys(storage["expected"], {"sizeBytes", "logicalSectorBytes", "modelSha256", "serialSha256"}, "storage.expected")
    descriptor = _keys(storage["descriptor"], {"diskById", "expected"}, "storage.descriptor")
    descriptor_expected = _keys(descriptor["expected"], {"sizeBytes", "logicalSectorBytes", "modelSha256", "serialSha256"}, "storage.descriptor.expected")
    if descriptor["diskById"] != storage["diskById"] or descriptor_expected != expected:
        raise ContractError("storage descriptor correspondence")
    _integer(expected["sizeBytes"], "storage.sizeBytes", positive=True)
    if expected["logicalSectorBytes"] not in {512, 4096}:
        raise ContractError("storage sector")
    _sha(expected["modelSha256"], "storage.modelSha256")
    _sha(expected["serialSha256"], "storage.serialSha256")
    trust = _keys(src["trust"], {"installAuthorizerPrincipal", "installAuthorizerPublicKey", "permanentLoginPublicKey", "finalHostPublicKey", "hostAgeRecipient", "recoveryAgeRecipient", "ciphertexts"}, "trust")
    public = {"state": "enrolled", "installAuthorizerPrincipal": _string(trust["installAuthorizerPrincipal"], re.compile(r"^[A-Za-z0-9._-]+$"), "principal"), "installAuthorizerPublicKey": trust["installAuthorizerPublicKey"], "installAuthorizerFingerprint": _fingerprint(trust["installAuthorizerPublicKey"], "install key"), "permanentLoginPublicKey": trust["permanentLoginPublicKey"], "permanentLoginFingerprint": _fingerprint(trust["permanentLoginPublicKey"], "login key"), "finalHostPublicKey": trust["finalHostPublicKey"], "finalHostFingerprint": _fingerprint(trust["finalHostPublicKey"], "host key")}
    secret = {"state": "enrolled", "hostAgeRecipient": trust["hostAgeRecipient"], "recoveryAgeRecipient": trust["recoveryAgeRecipient"], "ciphertexts": trust["ciphertexts"]}
    firmware = src["firmware"]
    if not isinstance(firmware, list) or not firmware:
        raise ContractError("firmware inventory")
    devices_input = _keys(src["devices"], {"audio", "bluetooth"}, "devices")
    for name in ("audio", "bluetooth"):
        device = devices_input[name]
        if not isinstance(device, dict) or device.get("state") not in {"present", "absent"}:
            raise ContractError(f"{name} state")
        if device["state"] == "present":
            _keys(device, {"state"}, name)
        else:
            row = _keys(device, {"state", "reason"}, name)
            if row["reason"] not in {"not-equipped", "unsupported", "deferred"}:
                raise ContractError(f"{name} absence")
    network = _keys(src["network"], {"policy", "capabilities", "rows", "remoteInstall", "fallback"}, "network")
    recovery_policy = _keys(network["fallback"], {"localConsole", "reconnect"}, "network.fallback")
    if recovery_policy["localConsole"] is not True or recovery_policy["reconnect"] is not True:
        raise ContractError("network fallback")
    network_capabilities = network["capabilities"]
    if network["policy"] != "networkmanager" or not isinstance(network_capabilities, list) or any(not isinstance(cap, str) or cap not in NETWORK_KEYS + ("local-console",) for cap in network_capabilities):
        raise ContractError("network capability list")
    capability_names = [cap for cap in network_capabilities if isinstance(cap, str)]
    if len(capability_names) != len(set(capability_names)):
        raise ContractError("network capability ordering")
    network_caps = sorted(set(capability_names).intersection(NETWORK_KEYS))
    remote = network["remoteInstall"]
    if not isinstance(remote, bool):
        raise ContractError("network.remoteInstall boolean")
    if remote and not set(network_caps) & {"network.ethernet", "network.usb-ethernet", "network.usb-tether"}:
        raise ContractError("remote install requires non-Wi-Fi network")
    rows = network["rows"]
    if not isinstance(rows, list):
        raise ContractError("network rows")
    devices = {"state": "enrolled", "firmware": firmware, "network": rows, "gpu": src["gpu"], "powerDaemon": src["powerDaemon"]}
    _validate_devices(devices)
    row_caps = sorted(str(row["capability"]) for row in rows if isinstance(row, dict) and isinstance(row.get("capability"), str))
    if row_caps != network_caps:
        raise ContractError("network row capability correspondence")
    capabilities = _capability_values(src, network_caps, remote)
    ddc = src["ddcConnectors"]
    _validate_ddc(ddc)
    gpu = src["gpu"]
    gpu_policy = "generic-vulkan" if gpu is not None else "cpu-only"
    declaration: JsonObject = {"hostId": host, "target": route[0], "system": route[1], "role": route[2], "identity": src["identity"], "location": src["location"], "display": src["display"], "boot": {"state": "uefi", "secureBoot": False, "configurationLimit": 10}, "storage": {"profile": "single-gpt-btrfs", "diskById": storage["diskById"], "expected": expected}, "publicTrust": public, "secretTrust": secret, "cpuVendor": vendor, "firmware": "redistributable", "kernel": "nixpkgs-default", "gpu": gpu_policy, "network": "networkmanager", "devices": devices, "capabilities": capabilities, "ddcConnectors": ddc, "remoteInstall": remote, "platformExpectations": src["platformExpectations"]}
    validate_declaration(declaration)
    return declaration


def read_fixture(path: str) -> JsonObject:
    """Read one canonical fixture without probing host hardware."""
    try:
        value = require_canonical(read_regular(Path(path)))
    except (OSError, CanonicalJsonError) as error:
        raise ContractError("fixture is not canonical JSON") from error
    return collect_fixture(value)

# Stable public alias for fixture-backed collection.
collect = collect_fixture
