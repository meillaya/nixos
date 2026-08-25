# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
# ─── How to run ───
# python3 -B -I bin/nix-config-hardware-intake validate INPUT PATCH
from __future__ import annotations

import copy
import hashlib
import re
from typing import Final, cast

from scripts.hardware.contracts import ContractError, JsonObject, declaration_digest, validate_declaration
from scripts.support.canonical_json import JsonValue, encode

MUTABLE_ROOTS: Final = {"location", "display", "boot", "storage", "publicTrust", "secretTrust", "cpuVendor", "firmware", "kernel", "gpu", "network", "devices", "capabilities", "ddcConnectors", "remoteInstall"}
IMMUTABLE_ROOTS: Final = {"hostId", "target", "system", "role", "identity", "platformExpectations"}
_OPS: Final = {"add", "remove", "replace"}


def _pointer(path: JsonValue) -> list[str]:
    if not isinstance(path, str) or not path.startswith("/") or path == "/":
        raise ContractError("JSON pointer")
    pieces = path[1:].split("/")
    result: list[str] = []
    for piece in pieces:
        if "~" in piece and piece not in {"~0", "~1"} and not re.fullmatch(r"(?:[^~]|~[01])+$", piece):
            raise ContractError("JSON pointer escape")
        result.append(piece.replace("~1", "/").replace("~0", "~"))
    root = result[0]
    if root in IMMUTABLE_ROOTS or root not in MUTABLE_ROOTS:
        raise ContractError("pointer outside Task-15 allowlist")
    if len(result) == 1 and root in {"location", "display", "boot", "storage", "publicTrust", "secretTrust", "devices", "capabilities"}:
        raise ContractError("parent replacement forbidden")
    return result


def _operation(value: JsonValue) -> JsonObject:
    if not isinstance(value, dict) or set(value) not in ({"op", "path", "value"}, {"op", "path"}):
        raise ContractError("patch operation shape")
    op = value["op"]
    if not isinstance(op, str) or op not in _OPS:
        raise ContractError("patch operation")
    path = _pointer(value["path"])
    if op in {"add", "replace"} and "value" not in value:
        raise ContractError("patch value missing")
    if op == "remove" and "value" in value:
        raise ContractError("patch remove value")
    if path[-1] == "-":
        raise ContractError("append pointer forbidden")
    return {"op": op, "path": "/" + "/".join(piece.replace("~", "~0").replace("/", "~1") for piece in path), **({"value": value["value"]} if "value" in value else {})}


def _get(root: JsonValue, path: list[str]) -> JsonValue:
    current = root
    for piece in path:
        if isinstance(current, dict) and piece in current:
            current = current[piece]
        elif isinstance(current, list) and piece.isdigit() and int(piece) < len(current):
            current = current[int(piece)]
        else:
            raise ContractError("patch path missing")
    return current


def _set(root: JsonValue, path: list[str], value: JsonValue, *, operation: str) -> None:
    if not path:
        raise ContractError("root replacement forbidden")
    parent = _get(root, path[:-1]) if path[:-1] else root
    leaf = path[-1]
    if isinstance(parent, dict):
        if operation == "remove" and leaf not in parent:
            raise ContractError("patch remove missing")
        if operation == "replace" and leaf not in parent:
            raise ContractError("patch replace missing")
        if operation == "add" and leaf not in parent and path[0] in {"cpuVendor", "firmware", "kernel", "gpu", "network", "remoteInstall"}:
            raise ContractError("patch add scalar missing")
        if operation == "remove":
            del parent[leaf]
        else:
            parent[leaf] = value
    elif isinstance(parent, list) and leaf.isdigit():
        index = int(leaf)
        if operation == "add" and index <= len(parent):
            parent.insert(index, value)
        elif operation == "replace" and index < len(parent):
            parent[index] = value
        elif operation == "remove" and index < len(parent):
            del parent[index]
        else:
            raise ContractError("patch array index")
    else:
        raise ContractError("patch parent missing")


def apply_intake(base: JsonValue, intake: JsonValue) -> JsonObject:
    """Apply and verify one canonical, reviewed RFC-6902 intake document."""
    if not isinstance(intake, dict) or set(intake) != {"schemaVersion", "hostId", "inputDeclarationDigest", "patch", "patchSha256", "outputDeclarationDigest", "reviewedBy", "appliedAt"}:
        raise ContractError("intake shape")
    if intake["schemaVersion"] != 1 or not isinstance(intake["patch"], list):
        raise ContractError("intake schema")
    parsed_base = validate_declaration(base)
    if intake["hostId"] != parsed_base["hostId"] or intake["inputDeclarationDigest"] != declaration_digest(parsed_base):
        raise ContractError("intake input digest")
    patch: list[JsonObject] = []
    previous_path = ""
    for raw in intake["patch"]:
        operation = _operation(raw)
        path = operation["path"]
        if not isinstance(path, str):
            raise ContractError("patch path")
        if path <= previous_path:
            raise ContractError("patch paths are not sorted and unique")
        previous_path = path
        patch.append(operation)
    if intake["patchSha256"] != hashlib.sha256(encode(cast(JsonValue, patch))).hexdigest():
        raise ContractError("patch digest")
    if not isinstance(intake["reviewedBy"], str) or re.fullmatch(r"[A-Za-z0-9._-]{1,64}", intake["reviewedBy"]) is None:
        raise ContractError("reviewer")
    if not isinstance(intake["appliedAt"], str) or re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", intake["appliedAt"]) is None:
        raise ContractError("appliedAt")
    result: JsonValue = copy.deepcopy(parsed_base)
    for operation in patch:
        path = _pointer(operation["path"])
        if operation["op"] == "remove":
            _set(result, path, None, operation="remove")
        else:
            _set(result, path, operation["value"], operation=str(operation["op"]))
    candidate = validate_declaration(result)
    if candidate["hostId"] != intake["hostId"] or declaration_digest(candidate) != intake["outputDeclarationDigest"]:
        raise ContractError("intake output digest")
    return candidate


def _escape(piece: str) -> str:
    return piece.replace("~", "~0").replace("/", "~1")


def _diff(base: JsonValue, candidate: JsonValue, path: str = "") -> list[JsonObject]:
    if isinstance(base, dict) and isinstance(candidate, dict):
        rows: list[JsonObject] = []
        for key in sorted(set(base) | set(candidate)):
            child = f"{path}/{_escape(key)}"
            if key not in base:
                rows.append({"op": "add", "path": child, "value": candidate[key]})
            elif key not in candidate:
                rows.append({"op": "remove", "path": child})
            else:
                rows.extend(_diff(base[key], candidate[key], child))
        return rows
    if isinstance(base, list) and isinstance(candidate, list):
        if base != candidate:
            return [{"op": "replace", "path": path, "value": candidate}]
        return []
    if base != candidate:
        return [{"op": "replace", "path": path, "value": candidate}]
    return []


def build_intake(base: JsonValue, candidate: JsonValue, reviewer: str, applied_at: str) -> JsonObject:
    """Create a deterministic intake document from two validated projections."""
    parsed_base = validate_declaration(base)
    parsed_candidate = validate_declaration(candidate)
    if parsed_base["hostId"] != parsed_candidate["hostId"]:
        raise ContractError("hostId cannot change")
    rows = [_operation(row) for row in _diff(parsed_base, parsed_candidate)]
    rows = sorted(rows, key=lambda row: str(row["path"]))
    if any(_pointer(row["path"])[0] in IMMUTABLE_ROOTS for row in rows):
        raise ContractError("immutable field changed")
    if not isinstance(reviewer, str) or re.fullmatch(r"[A-Za-z0-9._-]{1,64}", reviewer) is None:
        raise ContractError("reviewer")
    if not isinstance(applied_at, str) or re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", applied_at) is None:
        raise ContractError("appliedAt")
    return {"schemaVersion": 1, "hostId": parsed_base["hostId"], "inputDeclarationDigest": declaration_digest(parsed_base), "patch": cast(JsonValue, rows), "patchSha256": hashlib.sha256(encode(cast(JsonValue, rows))).hexdigest(), "outputDeclarationDigest": declaration_digest(parsed_candidate), "reviewedBy": reviewer, "appliedAt": applied_at}

# Stable public alias retained for callers that name the RFC-6902 operation.
apply_patch = apply_intake
