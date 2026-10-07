"""`zix pkg` - add, remove, pin and inspect packages across the config.

Three kinds of declaration are understood:

* the zix-managed set (``zix/managed/packages.nix``, installed on every host),
* the curated package lists (``modules/*/packages.nix``) through the zix
  marker blocks,
* version pins (``zix/managed/pins.json``), applied to every host's
  ``pkgs.<attr>`` through the multiverse overlay in ``lib/nixpkgs.nix``.

All edits are idempotent: adding what is already declared, removing what is
not, or re-pinning the same version are reported and change nothing.
"""

import json
import re

from . import nixedit, pins, tools
from .managed import Managed
from .util import ZixError, parse_spec, relpath, valid_name


# -- helpers -----------------------------------------------------------------

def _managed(ctx):
    return Managed(ctx.cfg, ctx.ui)


def show_change(ctx, path, old, new):
    rel = relpath(path, ctx.cfg.repo)
    if old == new:
        ctx.ui.note("  unchanged: %s" % rel)
        return
    diff = nixedit.unified_diff(old, new, "a/" + rel, "b/" + rel)
    for line in diff.split("\n"):
        if line.startswith("+") and not line.startswith("+++"):
            ctx.ui.say("  " + ctx.ui.green(line))
        elif line.startswith("-") and not line.startswith("---"):
            ctx.ui.say("  " + ctx.ui.red(line))
        elif line.startswith("@@"):
            ctx.ui.say("  " + ctx.ui.dim(line))


def _save_managed(ctx, managed):
    if ctx.dry_run:
        for path, text in managed.rendered().items():
            old = path.read_text() if path.exists() else ""
            show_change(ctx, path, old, text)
    else:
        managed.save()


def declared_where(ctx, name, managed=None):
    """Every place NAME is declared: [(target, path, line, kind)]."""
    managed = managed if managed is not None else _managed(ctx)
    hits = []
    if managed.has_package(name):
        hits.append(("managed", ctx.cfg.manifest_path, None, "managed"))
    for target, spec in ctx.cfg.list_targets().items():
        path = ctx.cfg.path(spec["file"])
        if not path.exists():
            continue
        for index in nixedit.token_lines(path.read_text(), name):
            hits.append((target, path, index + 1, "list"))
    modules = ctx.cfg.repo / "modules"
    if modules.is_dir():
        pattern = re.compile(r"(?<![\w.])pkgs\.%s\b" % re.escape(name))
        for path in sorted(modules.rglob("*.nix")):
            try:
                text = path.read_text()
            except (OSError, UnicodeDecodeError):
                continue
            for index, line in enumerate(text.split("\n")):
                if pattern.search(line):
                    hits.append(("aspect", path, index + 1, "aspect"))
    return hits


def _check_target(ctx, target):
    if target and target not in ctx.cfg.targets:
        raise ZixError("unknown target %r (known: %s)"
                       % (target, ", ".join(sorted(ctx.cfg.targets))))


def _edit_file(ctx, path, new_text):
    if ctx.dry_run:
        old = path.read_text()
        show_change(ctx, path, old, new_text)
        return
    nixedit.write_text(path, new_text)
    nixedit.validate_nix(ctx.runner, path)


# -- add ---------------------------------------------------------------------

def cmd_add(ctx, args):
    target = args.target or ctx.cfg.default_target
    _check_target(ctx, target)
    managed = _managed(ctx)
    for spec in args.specs:
        name, version = parse_spec(spec)
        if not valid_name(name):
            raise ZixError("invalid package name: %r" % name)
        if version:
            _add_pin(ctx, managed, name, version, target, args)
        else:
            _add_plain(ctx, managed, name, target)
    return 0


def _add_plain(ctx, managed, name, target):
    hits = declared_where(ctx, name, managed)
    if hits:
        places = ", ".join("%s (%s)" % (relpath(h[1], ctx.cfg.repo), h[0])
                           for h in hits)
        ctx.ui.ok("%s is already declared: %s" % (name, places))
        return False
    if (target or "managed") == "managed":
        managed.add_package(name, "managed")
        _save_managed(ctx, managed)
        ctx.ui.ok(
            "added %s to the zix-managed set (every host); "
            "use --target shared|linux|nixos|standalone|darwin for "
            "host-specific lists" % name)
        return True
    spec = ctx.cfg.targets[target]
    path = ctx.cfg.path(spec["file"])
    if not path.exists():
        raise ZixError("target file not found: %s" % path)
    old = path.read_text()
    new, added = nixedit.insert_token(old, name)
    if not added:
        ctx.ui.ok("%s is already present in %s" % (name, spec["file"]))
        return False
    if not ctx.dry_run:
        snapshot = ctx.backups.snapshot([path], "pkg-add")
        try:
            _edit_file(ctx, path, new)
        except BaseException:
            ctx.backups.restore(snapshot)
            raise
    else:
        _edit_file(ctx, path, new)
    ctx.ui.ok("added %s to %s (%s)" % (name, spec["file"], target))
    return True


def _add_pin(ctx, managed, name, version, target, args):
    if ctx.cfg.no_pins:
        raise ZixError(
            "version pins are disabled for this manifest (no_pins); install "
            "exact versions at runtime with `zix get %s@%s` instead"
            % (name, version))
    if not args.skip_check:
        ctx.ui.step("resolving %s versions via nixpkgs-multiverse ..." % name)
        pins.check_version(ctx, name, version)

    flake = ctx.cfg.path("flake.nix")
    files = [flake, ctx.cfg.path("flake.lock"), managed.path,
             ctx.cfg.packages_file, ctx.cfg.pins_file]
    declared = declared_where(ctx, name, managed)
    target_file = None
    if target and target != "managed":
        target_file = ctx.cfg.path(ctx.cfg.targets[target]["file"])
        files.append(target_file)

    if ctx.dry_run:
        ctx.ui.note("[dry-run] pin plan for %s@%s:" % (name, version))
        if not nixedit.has_input(flake.read_text(), pins.MULTIVERSE_INPUT):
            ctx.ui.say("  - add flake input %s = %s" % (
                pins.MULTIVERSE_INPUT, pins.MULTIVERSE_URL))
        if not declared:
            ctx.ui.say("  - declare %s (%s)" % (
                name, target or "managed"))
        managed.set_pin(name, version)
        _save_managed(ctx, managed)
        ctx.ui.say("  - pin %s = %s in zix/managed/pins.json" % (name, version))
        ctx.ui.note("[dry-run] no files changed")
        return True

    snapshot = ctx.backups.snapshot(files, "pkg-pin")
    try:
        input_added = pins.ensure_input(ctx)
        if input_added:
            pins.lock_flake(ctx)

        if not declared:
            if target_file is not None:
                old = target_file.read_text()
                new, added = nixedit.insert_token(old, name)
                if added:
                    _edit_file(ctx, target_file, new)
            else:
                managed.add_package(name, "managed")

        managed.set_pin(name, version)
        managed.save()

        if not args.no_verify:
            ctx.ui.step("verifying: evaluating pkgs.%s.version ..." % name)
            try:
                actual = pins.verify_pin(ctx, name, version)
            except pins.InconclusiveOrFailed as exc:
                if exc.looks_like_network:
                    ctx.ui.warn(
                        "could not verify the pin (looks like a network "
                        "problem); the config was left in place")
                    actual = None
                else:
                    raise
            if actual is not None and actual != version:
                raise ZixError(
                    "pin verification mismatch: pkgs.%s.version evaluates to "
                    "%s, expected %s" % (name, actual, version))

        where = target or "managed"
        ctx.ui.ok("pinned %s to %s%s and declared it in %s"
                  % (name, version,
                     " (new flake input added)" if input_added else "",
                     where if not declared else "its existing location"))
        return True
    except BaseException:
        ctx.backups.restore(snapshot)
        ctx.ui.warn("rolled back; snapshot kept at %s"
                    % relpath(snapshot.directory, ctx.cfg.repo))
        raise


# -- remove ------------------------------------------------------------------

def cmd_rm(ctx, args):
    _check_target(ctx, args.target)
    managed = _managed(ctx)
    for name in args.names:
        hits = declared_where(ctx, name, managed)
        aspects = [h for h in hits if h[3] == "aspect"]
        for _target, path, line, _kind in aspects:
            ctx.ui.warn(
                "%s is declared by hand in %s:%s; zix will not edit it"
                % (name, relpath(path, ctx.cfg.repo), line))
        hits = [h for h in hits if h[3] != "aspect"]
        selected = [h for h in hits
                    if not args.target or h[0] == args.target]
        pinned = managed.has_pin(name)
        if not selected and not pinned:
            if aspects:
                ctx.ui.say("nothing to remove: %s is only declared by hand"
                           % name)
            else:
                ctx.ui.say("nothing to remove: %s is not declared or pinned"
                           % name)
            continue
        if len(selected) > 1 and not args.all and not args.target:
            places = "\n".join("  %s (%s:%s)" % (h[0], relpath(h[1], ctx.cfg.repo),
                                                 h[2] or "-")
                               for h in selected)
            raise ZixError(
                "%s is declared in several targets:\n%s\n"
                "choose --target <name>, or --all to remove every occurrence"
                % (name, places))

        files = sorted({h[1] for h in selected}
                       | {managed.path, ctx.cfg.packages_file,
                          ctx.cfg.pins_file})
        snapshot = None if ctx.dry_run else ctx.backups.snapshot(files, "pkg-rm")
        try:
            removed_from = []
            for target, path, _line, kind in selected:
                if kind == "managed":
                    if managed.remove_package(name):
                        removed_from.append("managed")
                else:
                    old = path.read_text()
                    new, count = nixedit.remove_token(old, name)
                    if count:
                        _edit_file(ctx, path, new)
                        removed_from.append(target)
            if pinned:
                managed.remove_pin(name)
                removed_from.append("pin")
            _save_managed(ctx, managed)
        except BaseException:
            if snapshot:
                ctx.backups.restore(snapshot)
                ctx.ui.warn("rolled back; snapshot kept at %s"
                            % relpath(snapshot.directory, ctx.cfg.repo))
            raise
        ctx.ui.ok("removed %s from: %s" % (name, ", ".join(removed_from)))
    return 0


def cmd_unpin(ctx, args):
    managed = _managed(ctx)
    changed = False
    for name in args.names:
        if not managed.has_pin(name):
            ctx.ui.say("%s is not pinned" % name)
            continue
        managed.remove_pin(name)
        changed = True
        ctx.ui.ok("unpinned %s; it now follows nixpkgs again" % name)
    if changed:
        _save_managed(ctx, managed)
    return 0


# -- inspection --------------------------------------------------------------

def cmd_list(ctx, args):
    managed = _managed(ctx)
    if ctx.json_out:
        print(json.dumps(managed.data, indent=2, sort_keys=True))
        return 0
    ctx.ui.head("zix-managed packages (%d)" % len(managed.packages))
    if managed.packages:
        for entry in sorted(managed.packages, key=lambda p: p["name"]):
            ctx.ui.say("  %-28s target=%-10s added=%s"
                       % (entry["name"], entry.get("target", "?"),
                          entry.get("added", "?")))
    else:
        ctx.ui.note("  (none)")
    ctx.ui.head("pins (%d)" % len(managed.pins))
    if managed.pins:
        for name in sorted(managed.pins):
            info = managed.pins[name]
            ctx.ui.say("  %-28s = %s  (added %s)"
                       % (name, info["version"], info.get("added", "?")))
        flake = ctx.cfg.path("flake.nix")
        if (flake.exists()
                and not nixedit.has_input(flake.read_text(),
                                          pins.MULTIVERSE_INPUT)):
            ctx.ui.warn("pins exist but the multiverse input is missing from "
                        "flake.nix; run `zix pkg add %s@%s` to repair"
                        % (sorted(managed.pins)[0],
                           managed.pins[sorted(managed.pins)[0]]["version"]))
    else:
        ctx.ui.note("  (none; pin one with `zix pkg add NAME@VERSION`)")
    ctx.ui.note("look up a name with `zix pkg where NAME`")
    return 0


def cmd_where(ctx, args):
    managed = _managed(ctx)
    hits = declared_where(ctx, args.name, managed)
    for target, path, line, _kind in hits:
        location = relpath(path, ctx.cfg.repo)
        if line:
            location += ":%d" % line
        ctx.ui.say("  %-10s %s" % (target, location))
    if managed.has_pin(args.name):
        ctx.ui.say("  %-10s %s = %s"
                   % ("pin", args.name,
                      managed.pins[args.name]["version"]))
    if not hits and not managed.has_pin(args.name):
        ctx.ui.say("%s is not declared anywhere zix tracks" % args.name)
    return 0


def cmd_search(ctx, args):
    refs = ctx.cfg.search_refs or {"nixpkgs": "nixpkgs"}
    limit = args.limit or 15
    found_any = False
    for label, ref in refs.items():
        result = ctx.runner.run(
            ["nix", "--extra-experimental-features", "nix-command flakes",
             "search", "--json", ref, args.query],
            cwd=ctx.cfg.repo, check=False, capture=True)
        if result.returncode != 0:
            ctx.ui.warn("search failed for %s (%s)" % (label, ref))
            continue
        entries = json.loads(result.stdout or "{}")
        ctx.ui.head("%s (%s): %d match(es)" % (label, ref, len(entries)))
        for attr in sorted(entries)[:limit]:
            value = entries[attr]
            description = (value.get("description") or "").replace("\n", " ")
            ctx.ui.say("  %-45s %-16s %s"
                       % (attr, value.get("version") or "-", description[:80]))
        found_any = found_any or bool(entries)
    return 0 if found_any else 1


def cmd_versions(ctx, args):
    tools.run_tool(ctx, "multiverse", ["query", "versions", args.name],
                   mutating=False)
    return 0


def cmd_update(ctx, args):
    managed = _managed(ctx)
    names = list(args.names or sorted(managed.pins))
    if not names:
        ctx.ui.say("no pins to update; use `zix update` for a nixpkgs bump")
        return 0
    plan = []
    for name in names:
        if not managed.has_pin(name):
            ctx.ui.warn("%s is not pinned; skipping" % name)
            continue
        pinned_version = managed.pins[name]["version"]
        latest = pins.latest_version(ctx, name)
        plan.append((name, pinned_version, latest))
        state = "already latest" if pinned_version == latest \
            else "-> %s available" % latest
        ctx.ui.say("  %-28s pinned %-12s %s"
                   % (name, pinned_version, state))
    if not args.apply:
        ctx.ui.note("nothing changed; add --apply to move pins to the latest")
        return 0
    changed = [(n, old, new) for (n, old, new) in plan if old != new]
    if not changed:
        ctx.ui.ok("all pins already at the latest versions")
        return 0
    files = [managed.path, ctx.cfg.pins_file, ctx.cfg.packages_file,
             ctx.cfg.path("flake.lock")]
    snapshot = None if ctx.dry_run else ctx.backups.snapshot(files, "pkg-update")
    try:
        for name, _old, new in changed:
            managed.set_pin(name, new)
        _save_managed(ctx, managed)
        if not args.no_verify:
            for name, _old, new in changed:
                ctx.ui.step("verifying pkgs.%s.version ..." % name)
                try:
                    actual = pins.verify_pin(ctx, name, new)
                except pins.InconclusiveOrFailed as exc:
                    if exc.looks_like_network:
                        ctx.ui.warn("could not verify %s (network)" % name)
                        continue
                    raise
                if actual != new:
                    raise ZixError(
                        "verification mismatch for %s: got %s, expected %s"
                        % (name, actual, new))
        for name, old, new in changed:
            ctx.ui.ok("updated pin %s: %s -> %s" % (name, old, new))
        return 0
    except BaseException:
        if snapshot:
            ctx.backups.restore(snapshot)
            ctx.ui.warn("rolled back; snapshot kept at %s"
                        % relpath(snapshot.directory, ctx.cfg.repo))
        raise
