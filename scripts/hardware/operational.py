from __future__ import annotations

from scripts.hardware.primitives import JsonObject


def is_operationally_disabled(top: JsonObject) -> bool:
    return (
        top["boot"] == {"state": "disabled"}
        and top["storage"] == {"profile": "none"}
        and top["publicTrust"] == {"state": "disabled"}
        and top["secretTrust"] == {"state": "disabled"}
        and top["devices"] == {"state": "disabled"}
        and top["capabilities"] == {"state": "disabled"}
        and top["ddcConnectors"] == []
        and top["remoteInstall"] is False
    )
