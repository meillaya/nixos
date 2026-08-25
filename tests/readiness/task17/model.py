"""Pure capability projection checks used by the Task 17 readiness cases."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any

CapabilityMap = dict[str, dict[str, str]]

SERVICE_KEYS = ("audio", "bluetooth", "power", "suspend", "ddc", "gpu")


@dataclass(frozen=True, slots=True)
class ProjectionError(Exception):
    reason: str

    def __str__(self) -> str:
        return self.reason


def _present(machine: dict[str, Any], key: str) -> bool:
    capabilities = machine.get("capabilities", {})
    return capabilities.get("state") == "enrolled" and capabilities.get("values", {}).get(key, {}).get("state") == "present"


def project(machine: dict[str, Any]) -> dict[str, bool]:
    return {key: _present(machine, key) for key in SERVICE_KEYS}


def validate(machine: dict[str, Any]) -> None:
    """Reject capability projections that cannot be owned by this host."""
    projection = project(machine)
    system = machine["system"]
    policy = machine["gpu"]
    connectors = machine.get("ddcConnectors", [])
    devices = machine.get("devices", {})
    power_daemon = devices.get("powerDaemon")

    if system == "aarch64-darwin":
        if any(projection[key] for key in ("audio", "bluetooth", "power", "suspend", "ddc")):
            raise ProjectionError("Darwin cannot receive Linux device services")
        if policy != "apple-metal":
            raise ProjectionError("Darwin must retain Apple Metal policy")
    elif system == "x86_64-linux":
        pass
    else:
        raise ProjectionError("unsupported device-service platform")

    if projection["gpu"] != (policy == "generic-vulkan"):
        raise ProjectionError("GPU capability and policy disagree")
    if projection["power"] != (power_daemon == "power-profiles-daemon"):
        raise ProjectionError("power daemon must match the power capability")
    if projection["ddc"] != bool(connectors):
        raise ProjectionError("DDC requires at least one declared connector")
    if machine.get("role") != "workstation" and (projection["power"] or projection["suspend"]):
        raise ProjectionError("battery and suspend checks are only applicable to a laptop/workstation")


def enrolled_linux() -> dict[str, Any]:
    values: CapabilityMap = {key: {"state": "absent", "reason": "not-equipped"} for key in SERVICE_KEYS}
    for key in ("audio", "bluetooth", "power", "suspend", "ddc", "gpu"):
        values[key] = {"state": "present"}
    return {
        "hostId": "fixture-linux-laptop",
        "system": "x86_64-linux",
        "role": "workstation",
        "gpu": "generic-vulkan",
        "capabilities": {"state": "enrolled", "values": values},
        "devices": {"state": "enrolled", "powerDaemon": "power-profiles-daemon"},
        "ddcConnectors": [{"connector": "DP-1"}],
    }


def production_machines() -> list[dict[str, Any]]:
    disabled = {"state": "disabled"}
    return [
        {
            "hostId": "remembrance",
            "system": "x86_64-linux",
            "role": "workstation",
            "gpu": "disabled",
            "capabilities": disabled,
            "devices": disabled,
            "ddcConnectors": [],
        },
        {
            "hostId": "entropy",
            "system": "aarch64-darwin",
            "role": "workstation",
            "gpu": "apple-metal",
            "capabilities": disabled,
            "devices": disabled,
            "ddcConnectors": [],
        },
    ]


def negative_capability_applicability() -> int:
    candidate = enrolled_linux()
    candidate["role"] = "qualifier"
    try:
        validate(candidate)
    except ProjectionError:
        return 0
    return 1


def negative_cross_platform() -> int:
    candidate = enrolled_linux()
    candidate["system"] = "aarch64-darwin"
    candidate["gpu"] = "apple-metal"
    try:
        validate(candidate)
    except ProjectionError:
        return 0
    return 1


def fixture_projection() -> int:
    candidate = enrolled_linux()
    validate(candidate)
    assert project(candidate) == {key: True for key in SERVICE_KEYS}
    for production in production_machines():
        validate(production)
        assert project(production) == {key: False for key in SERVICE_KEYS}
    return 0


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("fixture", "N01-capability-applicability", "N03-cross-platform-service"))
    args = parser.parse_args()
    raise SystemExit(
        fixture_projection()
        if args.mode == "fixture"
        else negative_capability_applicability()
        if args.mode == "N01-capability-applicability"
        else negative_cross_platform()
    )
