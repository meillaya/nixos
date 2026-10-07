"""Cross-cutting commands: doctor, check, switch, update, follows, flakes,
grail, bin, wrap, and flake-input management."""

import json
import os
import shutil

from . import nixedit, pins, tools
from .cmd_pkg import show_change
from .util import ZixError, relpath


# -- doctor ------------------------------------------------------------------

def _first_line(text):
    lines = [line for line in (text or "").splitlines() if line.strip()]
    return lines[0] if lines else ""


def cmd_doctor(ctx, args):
    results = []

    def add(label, status, detail=""):
        results.append((label, status, detail))

    def guarded(label, fn):
        try:
            status, detail = fn()
        except Exception as exc:  # diagnosis must never crash
            status, detail = "fail", str(exc).splitlines()[0][:120]
        add(label, status, detail)

    add("repo", "ok", str(ctx.cfg.repo))

    def managed_files():
        if ctx.cfg.runtime_only:
            return "ok", "skipped (runtime-only manifest)"
        problems = []
        if not ctx.cfg.packages_file.exists():
            problems.append("packages.nix missing")
        else:
            ctx.runner.run(["nix-instantiate", "--parse",
                            str(ctx.cfg.packages_file)],
                           capture=True, check=True)

        if not ctx.cfg.pins_file.exists():
            problems.append("pins.json missing")
        else:
            json.loads(ctx.cfg.pins_file.read_text())
        return ("ok", "manifest, packages.nix and pins.json all valid") \
            if not problems else ("fail", "; ".join(problems))

    guarded("managed files", managed_files)

    def multiverse_input():
        if ctx.cfg.runtime_only:
            return "ok", "skipped (runtime-only manifest)"
        flake = ctx.cfg.path("flake.nix")
        if not flake.exists():
            return "fail", "flake.nix missing"
        text = flake.read_text()
        present = nixedit.has_input(text, pins.MULTIVERSE_INPUT)
        pins_count = len(json.loads(ctx.cfg.pins_file.read_text())) \
            if ctx.cfg.pins_file.exists() else 0
        if pins_count and not present:
            return "fail", "pins exist but the multiverse input is missing"
        if present:
            return "ok", "%s = %s" % (
                pins.MULTIVERSE_INPUT, nixedit.input_url(text, pins.MULTIVERSE_INPUT))
        return "ok", "not needed yet (no pins)"

    guarded("multiverse input", multiverse_input)

    def program(label, argv, parse):
        path = shutil.which(argv[0])
        if not path:
            return "fail", "%s not on PATH" % argv[0]
        result = ctx.runner.run(argv + parse, capture=True, check=False)
        return "ok", _first_line(result.stdout + result.stderr) or path

    guarded("nix", lambda: program("nix", ["nix"], ["--version"]))
    guarded("nix-instantiate", lambda: program(
        "nix-instantiate", ["nix-instantiate"], ["--version"]))

    def git_state():
        path = shutil.which("git")
        if not path:
            return "warn", "git not on PATH (backups still work)"
        result = ctx.runner.run(["git", "status", "--porcelain"],
                                cwd=ctx.cfg.repo, capture=True, check=False)
        dirty = len([l for l in result.stdout.splitlines() if l.strip()])
        return "ok", "%d uncommitted change(s)" % dirty

    guarded("git", git_state)

    def runtime():
        for candidate in ("podman", "docker"):
            path = shutil.which(candidate)
            if path:
                version = ctx.runner.run([candidate, "--version"], capture=True,
                                         check=False)
                fuse = " /dev/fuse present" if os.path.exists("/dev/fuse") else \
                    " (no /dev/fuse: omnibin sandboxes need it)"
                return "ok", "%s%s" % (_first_line(version.stdout), fuse)
        return "warn", "no podman/docker on PATH (sandbox commands disabled)"

    guarded("container runtime", runtime)

    def kvm():
        if os.path.exists("/dev/kvm"):
            mode = "rw" if os.access("/dev/kvm", os.R_OK | os.W_OK) else "not rw"
            return "ok", "/dev/kvm present (%s)" % mode
        return "warn", "no /dev/kvm (zix vm needs it)"

    guarded("kvm", kvm)

    def backups_writable():
        if ctx.dry_run:
            return "warn", "skipped (dry-run)"
        ctx.backups.root.mkdir(parents=True, exist_ok=True)
        probe = ctx.backups.root / ".probe"
        probe.write_text("ok")
        probe.unlink()
        return "ok", str(relpath(ctx.backups.root, ctx.cfg.repo))

    guarded("backups", backups_writable)

    add("tools", "ok", "%d configured (%s)"
        % (len(ctx.cfg.tools), ", ".join(sorted(ctx.cfg.tools))))

    symbols = {"ok": ctx.ui.green("ok  "), "warn": ctx.ui.yellow("warn"),
               "fail": ctx.ui.red("fail")}
    ctx.ui.head("zix doctor - %s" % ctx.cfg.name)
    failed = 0
    for label, status, detail in results:
        ctx.ui.say("  %s  %-18s %s" % (symbols[status], label, detail))
        failed += status == "fail"
    if failed:
        ctx.ui.error("%d problem(s) found" % failed)
        return 1
    ctx.ui.ok("no problems found")
    return 0


# -- check / switch / update -------------------------------------------------

def cmd_check(ctx, args):
    commands = [list(c) for c in ctx.cfg.checks.get("quick", [])]
    if args.full:
        commands += [list(c) for c in ctx.cfg.checks.get("full_extra", [])]
    if not commands:
        raise ZixError("no checks configured (checks.quick in zix.json)")
    failures = []
    for command in commands:
        label = " ".join(command)
        ctx.ui.step(label)
        result = ctx.runner.run(command, cwd=ctx.cfg.repo, capture=True,
                                check=False)
        if result.returncode == 0:
            ctx.ui.ok(_first_line(result.stdout) or "exit 0")
        else:
            failures.append(label)
            ctx.ui.error("failed: %s" % label)
            output = (result.stdout or "") + (result.stderr or "")
            for line in output.splitlines()[-30:]:
                ctx.ui.say("    " + line)
    if failures:
        ctx.ui.error("%d of %d check(s) failed" % (len(failures), len(commands)))
        return 1
    ctx.ui.ok("all %d check(s) passed" % len(commands))
    return 0


def cmd_switch(ctx, args):
    known = ctx.cfg.switches
    host = args.host
    extra = list(args.extra)
    # `zix switch -- --dry-run` parses the flag as the optional host; treat a
    # dash-leading token as app arguments for the default host instead.
    if host is not None and host not in known and host.startswith("-"):
        extra = [host] + extra
        host = None
    host = host or ctx.cfg.default_switch
    if not host:
        raise ZixError("no host given and no default_switch configured")
    if host not in known:
        raise ZixError("unknown host %r (known: %s)"
                       % (host, ", ".join(sorted(known))))
    argv = list(known[host]) + extra
    ctx.ui.step("switching %s: %s" % (host, " ".join(argv)))
    ctx.runner.run(argv, cwd=ctx.cfg.repo, mutating=True)
    return 0


def cmd_update(ctx, args):
    if not ctx.cfg.update_command:
        raise ZixError("no update_command configured in zix.json")
    ctx.runner.run(list(ctx.cfg.update_command) + list(args.extra),
                   cwd=ctx.cfg.repo, mutating=True)
    ctx.ui.note("inputs refreshed; `zix follows check` audits dedupe, "
                "`zix pkg update` refreshes pins")
    return 0


# -- follows (nix-auto-follow) ----------------------------------------------

def cmd_follows_check(ctx, args):
    result = tools.run_tool(ctx, "auto_follow", ["-c"], mutating=False,
                            capture=True, check=False)
    output = ((result.stdout or "") + (result.stderr or "")).strip()
    if result.returncode == 0:
        ctx.ui.ok(_first_line(output) or "all inputs dedupe")
        return 0
    ctx.ui.say(output)
    ctx.ui.error("the lock file is not fully deduped; see the suggestions "
                 "above (`zix follows fix` applies them)")
    return 1


def cmd_follows_fix(ctx, args):
    lock = ctx.cfg.path("flake.lock")
    snapshot = None if ctx.dry_run else ctx.backups.snapshot([lock], "follows-fix")
    result = tools.run_tool(ctx, "auto_follow", ["-i"], mutating=True,
                            capture=True, check=False, )
    output = ((result.stdout or "") + (result.stderr or "")).strip()
    if result.returncode != 0:
        if snapshot:
            ctx.backups.restore(snapshot)
        raise ZixError("auto-follow failed:\n%s" % output[-2000:])
    if ctx.dry_run:
        return 0
    diff = ctx.runner.run(["git", "diff", "--stat", "--", "flake.lock"],
                          cwd=ctx.cfg.repo, capture=True, check=False)
    ctx.ui.ok("flake.lock rewritten; " + (_first_line(diff.stdout) or "check "
             "`git diff flake.lock`"))
    if snapshot:
        ctx.ui.note("pre-change copy at %s"
                    % relpath(snapshot.directory, ctx.cfg.repo))
    return 0


# -- omniflake ---------------------------------------------------------------

def cmd_flakes_list(ctx, args):
    flake = ctx.cfg.tool("omniflake").get("flake")
    result = ctx.runner.run(["nix", "eval", "--json", "%s#lib.names" % flake],
                            cwd=ctx.cfg.repo, capture=True, check=True)
    names = json.loads(result.stdout or "[]")
    match = (args.match or "").lower()
    hits = [n for n in names if match in n.lower()] if match else list(names)
    limit = args.limit or 40
    ctx.ui.head("%d indexed flake(s)%s%s"
                % (len(hits), (" matching %r" % args.match) if match else "",
                   ("; showing %d" % limit) if len(hits) > limit else ""))
    for name in sorted(hits)[:limit]:
        ctx.ui.say("  " + name)
    ctx.ui.note("run one with: zix flakes run NAME -- --help")
    return 0


def cmd_flakes_run(ctx, args):
    flake = ctx.cfg.tool("omniflake").get("flake")
    prefix = "pinned" if args.pinned else "flakes"
    attr = args.attr or ("packages.%s.default" % ctx.cfg.system)
    target = "%s#%s.%s.%s" % (flake, prefix, args.name, attr)
    ctx.runner.run(["nix", "run", target, "--"] + list(args.extra),
                   cwd=ctx.cfg.repo, mutating=True)
    return 0


# -- tool passthroughs -------------------------------------------------------

def cmd_grail(ctx, args):
    tools.run_tool(ctx, "grail", args.args)
    return 0


def cmd_bin(ctx, args):
    tools.run_tool(ctx, "omnibin", args.args)
    return 0


def cmd_wrap(ctx, args):
    extra = list(args.args)
    if extra and not extra[0].startswith("-") and not os.path.exists(extra[0]):
        ctx.ui.warn("%s does not exist (wrap-buddy patches it in place)"
                    % extra[0])
    tools.run_tool(ctx, "wrap_buddy", extra)
    return 0


# -- flake inputs ------------------------------------------------------------

def cmd_input_ls(ctx, args):
    flake = ctx.cfg.path("flake.nix")
    text = flake.read_text()
    for name in nixedit.input_names(text):
        ctx.ui.say("  %-18s %s" % (name, nixedit.input_url(text, name) or ""))
    return 0


def cmd_input_add(ctx, args):
    flake = ctx.cfg.path("flake.nix")
    lock = ctx.cfg.path("flake.lock")
    text = flake.read_text()
    if nixedit.has_input(text, args.name):
        ctx.ui.ok("input %s is already present" % args.name)
        return 0
    follows = {}
    for item in (args.follows or []):
        path, sep, target = item.partition("=")
        if not sep:
            raise ZixError("--follows expects path=name, got %r" % item)
        follows[path.strip()] = target.strip()
    new, _ = nixedit.add_input(text, args.name, args.url, follows)
    if ctx.dry_run:
        show_change(ctx, flake, text, new)
        ctx.ui.note("[dry-run] no files changed")
        return 0
    snapshot = ctx.backups.snapshot([flake, lock], "input-add")
    try:
        nixedit.write_text(flake, new)
        nixedit.validate_nix(ctx.runner, flake)
        pins.lock_flake(ctx)
    except BaseException:
        ctx.backups.restore(snapshot)
        raise
    ctx.ui.ok("added input %s = %s" % (args.name, args.url))
    return 0


def cmd_input_remove(ctx, args):
    flake = ctx.cfg.path("flake.nix")
    lock = ctx.cfg.path("flake.lock")
    text = flake.read_text()
    if not nixedit.has_input(text, args.name):
        ctx.ui.ok("input %s is not present" % args.name)
        return 0
    new, count = nixedit.remove_input(text, args.name)
    if ctx.dry_run:
        show_change(ctx, flake, text, new)
        ctx.ui.note("[dry-run] no files changed")
        return 0
    snapshot = ctx.backups.snapshot([flake, lock], "input-remove")
    try:
        nixedit.write_text(flake, new)
        nixedit.validate_nix(ctx.runner, flake)
        pins.lock_flake(ctx)
    except BaseException:
        ctx.backups.restore(snapshot)
        raise
    ctx.ui.ok("removed input %s (%d line(s))" % (args.name, count))
    return 0
