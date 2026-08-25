from __future__ import annotations

import copy
from dataclasses import dataclass
from pathlib import Path
from typing import Final, TypedDict

from scripts.hardware.collector import collect_fixture
from scripts.support.canonical_json import JsonValue


class Fixture(TypedDict):
    source: dict[str, JsonValue]
    base: dict[str, JsonValue]


@dataclass(frozen=True, slots=True)
class FixtureFiles:
    source: dict[str, JsonValue]
    base: dict[str, JsonValue]


KEYS: Final = {
    "install": "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB+KdJg0/4H3SjCZ8V6XwM4ejauFvFzMnOut6sik5JMP",
    "login": "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKs5Y8NK91EH0gA0dGQ2c3Hww1KCGIQ/+HG3WRxTi88B",
    "host": "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGJKyAFI4o5FuS71bqj7vmMEh0YnJCXEjVL04JZeCXOE",
}


def make_fixture(root: Path) -> FixtureFiles:
    firmware = [
        {"logicalId": "display", "pciClass": "03:00:00", "expectedDriver": "i915", "firmwareExpectation": {"state": "driver-bound-no-load-failure"}},
        {"logicalId": "host-bridge", "pciClass": "06:00:00", "expectedDriver": "pcieport", "firmwareExpectation": {"state": "not-required", "reason": "device-has-no-loadable-firmware"}},
    ]
    capabilities = {"state": "enrolled", "values": {key: {"state": "absent", "reason": "not-equipped"} for key in ("install.direct", "install.remote", "reboot", "rollback", "firmware", "microcode", "network.ethernet", "network.usb-ethernet", "network.usb-tether", "network.wifi", "recovery.local-console", "gpu", "audio", "bluetooth", "power", "suspend", "ddc", "session", "portal-obs", "theme-kitty")}}
    for key in ("install.direct", "reboot", "rollback", "firmware", "microcode", "network.ethernet", "recovery.local-console", "gpu", "power", "suspend", "ddc", "session", "portal-obs", "theme-kitty"):
        capabilities["values"][key] = {"state": "present"}
    source: dict[str, JsonValue] = {
        "schemaVersion": 1,
        "hostId": "remembrance",
        "target": "nixosConfigurations.remembrance",
        "system": "x86_64-linux",
        "role": "workstation",
        "identity": {"name": "mei", "home": "/home/mei", "uid": 1000, "gid": 100},
        "location": {"timeZone": "America/New_York", "locale": "en_US.UTF-8", "keymap": "us", "xkb": "us"},
        "display": {"scale": {"numerator": 1, "denominator": 1}},
        "cpu": {"vendor": "GenuineIntel"},
        "uefi": {"secureBoot": False, "configurationLimit": 10},
        "storage": {"diskById": "nvme-fixture-model", "expected": {"sizeBytes": 1000204886016, "logicalSectorBytes": 512, "modelSha256": "1" * 64, "serialSha256": "2" * 64}, "descriptor": {"diskById": "nvme-fixture-model", "expected": {"sizeBytes": 1000204886016, "logicalSectorBytes": 512, "modelSha256": "1" * 64, "serialSha256": "2" * 64}}},
        "trust": {"installAuthorizerPrincipal": "fixture-installer", "installAuthorizerPublicKey": KEYS["install"], "permanentLoginPublicKey": KEYS["login"], "finalHostPublicKey": KEYS["host"], "hostAgeRecipient": "age1" + "q" * 58, "recoveryAgeRecipient": "age1" + "p" * 58, "ciphertexts": [{"path": "secrets/fixture/host.age", "sha256": "3" * 64}, {"path": "secrets/fixture/recovery.age", "sha256": "4" * 64}]},
        "firmware": firmware,
        "gpu": {"expectedDriver": "i915", "expectedRendererDigest": "5" * 64},
        "network": {"policy": "networkmanager", "capabilities": ["network.ethernet"], "fallback": {"localConsole": True, "reconnect": True}, "rows": [{"capability": "network.ethernet", "controllerClass": "02:00:00", "expectedDriver": "e1000e", "firmwareExpectation": {"state": "driver-bound-no-load-failure"}}], "remoteInstall": False},
        "powerDaemon": "power-profiles-daemon",
        "devices": {"audio": {"state": "present"}, "bluetooth": {"state": "present"}},
        "capabilities": capabilities,
        "ddcConnectors": [{"connector": "DP-1", "i2cLocatorDigest": "6" * 64, "sysfsConnectorDigest": "7" * 64}],
        "platformExpectations": {"kind": "none"},
    }
    base = copy.deepcopy(collect_fixture(source))
    base["cpuVendor"] = "pending"
    base["boot"] = {"state": "disabled"}
    base["storage"] = {"profile": "none"}
    base["publicTrust"] = {"state": "disabled"}
    base["secretTrust"] = {"state": "disabled"}
    base["firmware"] = "disabled"
    base["kernel"] = "disabled"
    base["gpu"] = "disabled"
    base["network"] = "disabled"
    base["devices"] = {"state": "disabled"}
    base["capabilities"] = {"state": "disabled"}
    base["ddcConnectors"] = []
    base["remoteInstall"] = False
    base["platformExpectations"] = {"kind": "none"}
    return FixtureFiles(source=source, base=base)
