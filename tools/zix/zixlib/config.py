"""Repository discovery and zix.json loading.

zix is generic: everything repo-specific lives in the ``zix.json`` manifest at
the repository root. Finding the repo is a walk up from the current directory
(or ``--repo`` / ``ZIX_REPO``), so the tool works from any subdirectory and can
be pointed at other people's configurations unchanged. When the walk finds
nothing, a system-wide manifest (``/etc/zix/zix.json``; override with
``ZIX_SYSTEM_CONFIG``) is used - that is what images ship so commands like
``zix get`` work with no checkout on disk.
"""

import json
import os
from pathlib import Path

from .util import ZixError

CONFIG_NAME = "zix.json"
SUPPORTED_VERSION = 1


class Config:
    def __init__(self, repo, data):
        self.repo = Path(repo)
        self.data = data
        self.name = data.get("name", self.repo.name)
        self.description = data.get("description", "")
        self.system = data.get("system") or default_system()
        self.targets = data.get("targets", {})
        self.default_target = data.get("default_target")
        # Manifests without a pin overlay (no lib/nixpkgs.nix policy) set this
        # and send exact versions to `zix get` at runtime instead.
        self.no_pins = bool(data.get("no_pins", False))
        self.managed = data.get("managed", {})
        self.policy_file = data.get("policy_file", "lib/nixpkgs.nix")
        self.checks = data.get("checks", {})
        self.switches = data.get("switches", {})
        self.default_switch = data.get("default_switch")
        self.update_command = data.get("update_command", [])
        self.search_refs = data.get("search", {})
        self.tools = data.get("tools", {})
        self.companion_inputs = data.get("companion_inputs", {})
        self.sandbox = data.get("sandbox", {})
        self.vm = data.get("vm", {})
        # A runtime-only manifest ships in images: no package lists, no
        # flake.nix, no pins - just enough config for `zix get` and friends.
        self.runtime_only = bool(data.get("runtime_only", False))

    # -- paths ---------------------------------------------------------------

    def path(self, relative):
        return self.repo / relative

    @property
    def manifest_path(self):
        return self.path(self.managed.get("manifest", "zix/managed/manifest.json"))

    @property
    def packages_file(self):
        return self.path(self.managed.get("packages_file", "zix/managed/packages.nix"))

    @property
    def pins_file(self):
        return self.path(self.managed.get("pins_file", "zix/managed/pins.json"))

    def list_targets(self):
        """Targets backed by a hand-maintained package list file."""
        return {name: t for name, t in self.targets.items()
                if t.get("kind", "list") == "list" and t.get("file")}

    def tool(self, name):
        tool = self.tools.get(name)
        if not tool:
            raise ZixError(
                "tool %r is not configured in %s (tools.%s)"
                % (name, CONFIG_NAME, name))
        return tool


def default_system():
    import platform
    machine = platform.machine()
    if platform.system() == "Darwin":
        return "aarch64-darwin" if machine == "arm64" else "x86_64-darwin"
    return "aarch64-linux" if machine in ("aarch64", "arm64") else "x86_64-linux"


def discover_repo(start=None, explicit=None):
    env = os.environ.get("ZIX_REPO")
    if explicit:
        root = Path(explicit).expanduser().resolve()
        if not (root / CONFIG_NAME).exists():
            raise ZixError("no %s found in %s" % (CONFIG_NAME, root))
        return root
    if env:
        root = Path(env).expanduser().resolve()
        if not (root / CONFIG_NAME).exists():
            raise ZixError("ZIX_REPO=%s has no %s" % (env, CONFIG_NAME))
        return root
    here = Path(start or os.getcwd()).resolve()
    for candidate in [here] + list(here.parents):
        if (candidate / CONFIG_NAME).exists():
            return candidate
    system = Path(os.environ.get("ZIX_SYSTEM_CONFIG", "/etc/zix"))
    if (system / CONFIG_NAME).exists():
        return system
    raise ZixError(
        "no %s found from %s upwards (and no system manifest at %s); "
        "run from the repo or pass --repo" % (CONFIG_NAME, here, system))


def load_config(repo):
    repo = Path(repo)
    try:
        data = json.loads((repo / CONFIG_NAME).read_text())
    except json.JSONDecodeError as exc:
        raise ZixError("%s is not valid JSON: %s" % (repo / CONFIG_NAME, exc))
    version = data.get("version")
    if version != SUPPORTED_VERSION:
        raise ZixError(
            "unsupported %s version %r (expected %d)"
            % (CONFIG_NAME, version, SUPPORTED_VERSION))
    return Config(repo, data)
