# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
# Enrolled x86 correspondence checks for the hardware declaration contract.
from __future__ import annotations

from scripts.hardware.primitives import ContractError, JsonObject
from scripts.support.canonical_json import JsonValue


def _object(value: JsonValue, label: str) -> JsonObject:
    if not isinstance(value, dict):
        raise ContractError(f"{label} object")
    return value


def _field_string(value: JsonObject, key: str, label: str) -> str:
    field = value.get(key)
    if not isinstance(field, str):
        raise ContractError(f"{label} string")
    return field


def validate_x86_enrollment(
    top: JsonObject,
    boot: JsonObject,
    storage: JsonObject,
    public_trust: JsonObject,
    secret_trust: JsonObject,
    platform_expectations: JsonObject,
    devices: JsonObject,
    capabilities: JsonObject,
    network_rows: list[JsonObject],
) -> None:
    if _field_string(boot, "state", "boot.state") != "uefi" or _field_string(storage, "profile", "storage.profile") != "single-gpt-btrfs":
        raise ContractError("x86 enrollment closure")
    if _field_string(public_trust, "state", "publicTrust.state") != "enrolled" or _field_string(secret_trust, "state", "secretTrust.state") != "enrolled":
        raise ContractError("x86 trust enrollment")
    if top["firmware"] != "redistributable" or top["kernel"] != "nixpkgs-default" or top["network"] != "networkmanager":
        raise ContractError("x86 policy closure")
    if platform_expectations["kind"] != "none" or _field_string(capabilities, "state", "capabilities.state") != "enrolled" or _field_string(devices, "state", "devices.state") != "enrolled":
        raise ContractError("x86 capability enrollment")
    values = _object(capabilities["values"], "capabilities.values")
    network_values = [
        name
        for name in ("network.ethernet", "network.usb-ethernet", "network.usb-tether", "network.wifi")
        if _field_string(_object(values[name], f"capabilities.values.{name}"), "state", f"capabilities.values.{name}.state") == "present"
    ]
    declared_networks = [_field_string(row, "capability", "network.capability") for row in network_rows]
    if network_values != declared_networks:
        raise ContractError("network capability correspondence")
    power_present = _field_string(_object(values["power"], "capabilities.values.power"), "state", "capabilities.values.power.state") == "present"
    if power_present != (devices["powerDaemon"] == "power-profiles-daemon"):
        raise ContractError("power capability correspondence")
    gpu_present = _field_string(_object(values["gpu"], "capabilities.values.gpu"), "state", "capabilities.values.gpu.state") == "present"
    if gpu_present != (devices["gpu"] is not None) or top["gpu"] != ("generic-vulkan" if gpu_present else "cpu-only"):
        raise ContractError("gpu capability correspondence")
    ddc_present = _field_string(_object(values["ddc"], "capabilities.values.ddc"), "state", "capabilities.values.ddc.state") == "present"
    if ddc_present != (top["ddcConnectors"] != []):
        raise ContractError("ddc capability correspondence")
    required = ("install.direct", "reboot", "rollback", "firmware", "microcode", "recovery.local-console", "session", "portal-obs", "theme-kitty")
    if any(_object(values[name], f"capabilities.values.{name}") != {"state": "present"} for name in required):
        raise ContractError("required capabilities")
    if top["remoteInstall"] and not set(network_values) & {"network.ethernet", "network.usb-ethernet", "network.usb-tether"}:
        raise ContractError("remote requires wired capability")
    if top["remoteInstall"] != (_object(values["install.remote"], "capabilities.values.install.remote") == {"state": "present"}):
        raise ContractError("remote capability")
