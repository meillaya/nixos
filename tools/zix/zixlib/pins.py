"""Version pinning through nixpkgs-multiverse.

A pin means: every host's ``pkgs.<attr>`` becomes the exact version named,
resolved through ``inputs.multiverse.lib.pinOverlay`` applied in
``lib/nixpkgs.nix``. That layer survives ``home-manager.useGlobalPkgs = true``
(where per-HM overlays are discarded) and reaches NixOS, nix-darwin and the
standalone Home Manager alike, because all of them take their package set from
``mkPkgs``.

What a pin touches:

* ``flake.nix`` - ensures the ``multiverse`` companion input exists.
* unique to the pin registry - ``zix/managed/manifest.json`` + ``pins.json``.
* optionally the declaration of the package itself (so something installs it).

The heavy machinery (clingo? no - greedy solver, fetchTree of historical
nixpkgs) is multiverse's; zix resolves versions with its ``mvs`` CLI and
verifies the outcome by evaluating the pinned attribute's version.
"""

from . import nixedit
from .util import ZixError
import json

MULTIVERSE_INPUT = "multiverse"
MULTIVERSE_URL = "github:fzakaria/nixpkgs-multiverse"


def parse_versions(mvs_output):
    """Extract version strings from `mvs query versions` output.

    The table prints ``VERSION  FIRST  LAST  REVS`` with one row per version;
    everything up to the first row that looks like a version is dropped.
    """
    versions = []
    for line in mvs_output.splitlines():
        line = line.strip()
        if not line:
            continue
        first = line.split()[0]
        if first[0].isdigit() and ("." in first or first.isdigit()):
            if first not in versions:
                versions.append(first)
    return versions


def _mvs(ctx, subcommand_args, mutating=False):
    tool = ctx.cfg.tool("multiverse")
    argv = list(tool["command"]) + subcommand_args
    result = ctx.runner.run(argv, check=False, capture=True,
                            mutating=mutating)
    if result.returncode != 0:
        raise ZixError(
            "mvs %s failed (exit %d):\n%s"
            % (" ".join(subcommand_args), result.returncode,
               (result.stderr or result.stdout or "").strip()[-2000:]))
    return result.stdout


def resolve_versions(ctx, attr):
    """Every version of ``attr`` that ever shipped, oldest first."""
    output = _mvs(ctx, ["query", "versions", "--json", attr])
    try:
        payload = json.loads(output)
    except json.JSONDecodeError:
        # Older mvs builds print the table only; keep a parser for those.
        return parse_versions(output)
    return [entry["version"] for entry in payload.get("versions", [])]


def latest_version(ctx, attr):
    versions = resolve_versions(ctx, attr)
    if not versions:
        raise ZixError("no versions found for %r in the multiverse index" % attr)
    return versions[-1]


def check_version(ctx, attr, version):
    """Fail with the available versions when ``version`` never shipped."""
    versions = resolve_versions(ctx, attr)
    if not versions:
        raise ZixError("no versions found for %r in the multiverse index" % attr)
    if version not in versions:
        recent = ", ".join(versions[-8:])
        raise ZixError(
            "%s@%s never shipped in nixpkgs; recent versions: %s"
            % (attr, version, recent))
    return versions


def ensure_input(ctx):
    """Make sure flake.nix declares the multiverse input. Returns changed."""
    flake = ctx.cfg.path("flake.nix")
    if not flake.exists():
        raise ZixError("flake.nix not found at %s" % flake)
    text = flake.read_text()
    if nixedit.has_input(text, MULTIVERSE_INPUT):
        return False
    new_text, _ = nixedit.add_input(
        text, MULTIVERSE_INPUT, MULTIVERSE_URL)
    nixedit.write_text(flake, new_text)
    nixedit.validate_nix(ctx.runner, flake)
    ctx.ui.step("added flake input %s = %s" % (MULTIVERSE_INPUT, MULTIVERSE_URL))
    return True


def lock_flake(ctx):
    ctx.runner.run(["nix", "flake", "lock"], cwd=ctx.cfg.repo,
                   mutating=True)


def verify_pin(ctx, attr, version):
    """Evaluate ``pkgs.<attr>.version`` through the policy overlay.

    Returns the observed version. Raises ZixError when the evaluation fails
    (the caller decides whether that is a real problem or an offline machine -
    see ``inconclusive_eval``).
    """
    expr = (
        "let f = builtins.getFlake (toString %s); "
        "p = (import (toString %s) { inputs = f.inputs; }).mkPkgs \"%s\"; "
        "in p.%s.version"
        % (_nix_path(ctx.cfg.repo),
           _nix_path(ctx.cfg.path(ctx.cfg.policy_file)),
           ctx.cfg.system, attr))
    result = ctx.runner.run(
        ["nix", "eval", "--raw", "--impure", "--expr", expr],
        cwd=ctx.cfg.repo, check=False, capture=True)
    if result.returncode != 0:
        detail = (result.stderr or result.stdout or "").strip()
        raise InconclusiveOrFailed(detail)
    return result.stdout.strip()


def _nix_path(path):
    return '"%s"' % str(path)


class InconclusiveOrFailed(ZixError):
    """Verification could not complete (offline, fetch error, eval error).

    The caller distinguishes network flakiness from real failure by scanning
    ``message`` for download markers and either warns or rolls back.
    """

    def __init__(self, detail):
        super().__init__("pin verification failed:\n%s" % detail[-3000:])
        self.detail = detail

    @property
    def looks_like_network(self):
        markers = ("unable to download", "Could not resolve host",
                   "download of", "TLS", "connection", "timed out")
        return any(m.lower() in self.detail.lower() for m in markers)
