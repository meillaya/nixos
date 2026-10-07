"""``zix get`` - install a package into a nix profile, right now.

The runtime counterpart of ``zix pkg add``: ``pkg add`` edits the repo's
declarative package lists (the next rebuild installs them); ``get`` installs
immediately, edits no repository files, and works without a zix.json - which
is what makes it usable inside images and on machines that never carry the
configuration repo.

Packages resolve through nixpkgs-multiverse's store-path index, which maps
every version nixpkgs ever shipped to the store path its build produced:
``get hello@2.10`` installs that exact build without evaluating nixpkgs (the
fast road). When the index has no match, ``get`` falls back to the evaluating
road and says so.
"""

import json
import re
import shutil

from . import pins
from .util import ZixError, parse_spec, valid_name

FAST = pins.MULTIVERSE_URL + "#fast"
EVAL = pins.MULTIVERSE_URL + "#versions"


def fast_ref(attr, version):
    """Multiverse store-path-index ref for ATTR@VERSION (or its latest)."""
    if version:
        return '%s.versions.%s."%s".out' % (FAST, attr, version)
    return "%s.latest.%s.out" % (FAST, attr)


def eval_ref(attr, version):
    """The evaluating road (fetches nixpkgs; heavier, always complete)."""
    if version:
        return '%s.%s."%s"' % (EVAL, attr, version)
    return "nixpkgs#%s" % attr


def _profile_args(args):
    return ["--profile", args.profile] if args.profile else []


def _profile_verb(ctx):
    """`nix profile add` on nix >= 2.25, `install` on older builds (2.23)."""
    probe = ctx.runner.run(["nix", "profile", "add", "--help"],
                           check=False, capture=True, quiet=True)
    return "add" if probe.returncode == 0 else "install"


def _install_argv(ctx, args, ref):
    return (["nix", "profile", _profile_verb(ctx)] + _profile_args(args)
            + ["--extra-experimental-features", "nix-command flakes", ref])


def _profile_entries(ctx, args):
    """The profile's elements as dicts (each carrying its name), or None."""
    result = ctx.runner.run(
        ["nix", "profile", "list"] + _profile_args(args) + ["--json"],
        check=False, capture=True)
    if result.returncode != 0:
        return _profile_entries_plain(ctx, args)
    try:
        payload = json.loads(result.stdout or "{}")
    except json.JSONDecodeError:
        return _profile_entries_plain(ctx, args)
    elements = payload.get("elements") if isinstance(payload, dict) else None
    if isinstance(elements, dict):
        elements = [dict(entry, name=entry.get("name", key))
                    for key, entry in elements.items()]
    return elements or []


def _profile_entries_plain(ctx, args):
    """Fallback for older nix builds without `profile list --json`."""
    result = ctx.runner.run(
        ["nix", "profile", "list"] + _profile_args(args),
        check=False, capture=True)
    if result.returncode != 0:
        return None
    entries, current = [], None
    for raw in (result.stdout or "").splitlines():
        line = re.sub(r"\x1b\[[0-9;]*m", "", raw).strip()
        if line.startswith("Name:"):
            current = {"name": line.split(":", 1)[1].strip(),
                       "storePaths": []}
            entries.append(current)
        elif line.startswith("Store paths:") and current is not None:
            current["storePaths"] = line.split(":", 1)[1].split()
    return entries or None


def _entry_matches(entry, name):
    """True for NAME and for nix's NAME-2 style collision suffixes."""
    entry_name = str(entry.get("name", ""))
    return (entry_name == name
            or bool(re.fullmatch(re.escape(name) + r"-\d+", entry_name)))


def _report(ctx, args, name):
    """Say where the binary lands; warn when it is not reachable on PATH."""
    if ctx.dry_run:
        return
    for entry in _profile_entries(ctx, args) or []:
        paths = entry.get("storePaths") or []
        if entry.get("name") == name and paths:
            ctx.ui.note("  %s -> %s" % (name, paths[0]))
    found = shutil.which(name)
    if found:
        ctx.ui.ok("%s is on PATH (%s)" % (name, found))
    elif not args.profile:
        ctx.ui.warn(
            "%s installed, but not on PATH: add ~/.nix-profile/bin to PATH "
            "(the profile `get` writes)" % name)


def cmd_get(ctx, args):
    if args.list:
        result = ctx.runner.run(
            ["nix", "profile", "list"] + _profile_args(args)
            + (["--json"] if ctx.json_out else []),
            check=False, capture=True)
        ctx.ui.say((result.stdout or "").strip())
        if (result.stderr or "").strip():
            ctx.ui.note(result.stderr.strip())
        return result.returncode

    if not args.specs:
        raise ZixError("nothing to get: pass NAME[@VERSION], or --list")

    for spec in args.specs:
        name, version = parse_spec(spec)
        if not valid_name(name):
            raise ZixError("invalid package name: %r" % name)
        attr = args.attr or name
        label = name + ("@" + version if version else "")

        if not ctx.dry_run:
            existing = [e for e in (_profile_entries(ctx, args) or [])
                        if _entry_matches(e, name)]
            same = [e for e in existing
                    if not version or any(version in p for p in
                                          e.get("storePaths") or [])]
            if same and not args.force:
                paths = (same[0].get("storePaths") or ["?"])[0]
                ctx.ui.ok("%s is already installed (%s); use --force to "
                          "reinstall it" % (label, paths))
                _report(ctx, args, name)
                continue
            if existing:
                ctx.ui.warn("a different version of %s is already in this "
                            "profile; nix keeps both entries (remove the old "
                            "one with `nix profile remove NAME`)" % name)

        road = eval_ref if args.eval_road else fast_ref
        ctx.ui.step("getting %s (%s road) ..."
                    % (label, "evaluating" if args.eval_road
                       else "store-path index"))
        result = ctx.runner.run(_install_argv(ctx, args, road(attr, version)),
                                mutating=True, check=False)
        if result.returncode != 0 and not args.eval_road:
            ctx.ui.warn(
                "the store-path index had no %s; falling back to the "
                "evaluating road (fetches nixpkgs, needs more memory)" % label)
            result = ctx.runner.run(
                _install_argv(ctx, args, eval_ref(attr, version)),
                mutating=True, check=False)
        if result.returncode != 0:
            raise ZixError(
                "could not install %s; check the attribute name and version "
                "(zix pkg versions NAME lists what nixpkgs shipped)" % label)
        ctx.ui.ok("got %s" % label)
        _report(ctx, args, name)
    return 0
