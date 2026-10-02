"""`zix sandbox` - disposable container sandboxes for agent work.

The default image is omnibin's: every binary nixpkgs ever shipped, mounted
lazily from the cache. An agent sandbox wants exactly that - nothing to
install, everything available - and zix only has to add the two things the
container needs (``/dev/fuse`` and ``SYS_ADMIN``, from zix.json), the
workspace mount, and an optional agent-config mount.

Subcommands:

    zix sandbox run [--image IMG] [--agent claude] [-- CMD...]
    zix sandbox ls [-a]
    zix sandbox exec [NAME] [-- CMD...]
    zix sandbox rm [NAME | --all]
"""

import os
import re
import shutil
from pathlib import Path

from .util import ZixError


def _runtime(ctx):
    configured = ctx.cfg.sandbox.get("runtime", "auto")
    if configured in ("podman", "docker"):
        if shutil.which(configured) is None:
            raise ZixError("%s is configured but not on PATH" % configured)
        return configured
    for candidate in ("podman", "docker"):
        if shutil.which(candidate):
            return candidate
    raise ZixError("no container runtime found (install podman or docker)")


def _slug(text):
    return re.sub(r"[^a-z0-9_.-]+", "-", text.lower()).strip("-") or "sandbox"


def _prefix(ctx):
    return ctx.cfg.sandbox.get("name_prefix", "zix-")


def _agent_mounts(ctx, agent):
    if not agent:
        return []
    table = ctx.cfg.sandbox.get("agent_mounts", {}).get(agent)
    if table is None:
        known = ", ".join(sorted(ctx.cfg.sandbox.get("agent_mounts", {})))
        raise ZixError("unknown agent %r (configured: %s)" % (agent, known))
    mounts = []
    for host, container in table:
        host_path = Path(os.path.expanduser(host))
        if not host_path.exists():
            ctx.ui.warn("skipping mount %s (does not exist)" % host_path)
            continue
        mounts += ["-v", "%s:%s" % (host_path, container)]
    return mounts


def cmd_run(ctx, args):
    runtime = _runtime(ctx)
    sandbox = ctx.cfg.sandbox
    workspace = str(Path(args.workspace or os.getcwd()).resolve())
    workdir = sandbox.get("workdir", "/workspace")
    name = args.name or (_prefix(ctx) + _slug(Path(workspace).name))
    argv = [runtime, "run"]
    if not args.detach:
        argv += ["-it"]
    if not args.keep:
        argv += ["--rm"]
    argv += ["--name", name, "-v", "%s:%s" % (workspace, workdir),
             "-w", workdir]
    argv += list(sandbox.get("run_args", []))
    argv += _agent_mounts(ctx, args.agent)
    argv += [args.image or sandbox.get("image", "docker.io/library/debian:stable")]
    argv += list(args.cmds)
    if args.detach:
        ctx.ui.note("starting detached as %s; attach with "
                    "`zix sandbox exec %s`" % (name, name))
    ctx.runner.run(argv, cwd=ctx.cfg.repo, mutating=True)
    return 0


def cmd_ls(ctx, args):
    runtime = _runtime(ctx)
    argv = [runtime, "ps", "--format",
            "{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}"]
    if args.all:
        argv.append("-a")
    argv += ["--filter", "name=%s" % _prefix(ctx)]
    result = ctx.runner.run(argv, cwd=ctx.cfg.repo, capture=True, check=False)
    lines = [l for l in (result.stdout or "").splitlines() if l.strip()]
    if not lines:
        ctx.ui.say("no sandboxes")
        return 0
    for line in lines:
        ctx.ui.say("  " + line)
    return 0


def _latest(ctx, runtime):
    result = ctx.runner.run(
        [runtime, "ps", "-q", "--filter", "name=%s" % _prefix(ctx), "-n", "1"],
        cwd=ctx.cfg.repo, capture=True, check=False)
    lines = [l.strip() for l in (result.stdout or "").splitlines() if l.strip()]
    return lines[0] if lines else None


def cmd_exec(ctx, args):
    runtime = _runtime(ctx)
    name = args.name or _latest(ctx, runtime)
    if not name:
        raise ZixError("no running zix sandbox found (start one with "
                       "`zix sandbox run`)")
    command = list(args.cmds) or ["bash"]
    ctx.runner.run([runtime, "exec", "-it", name] + command,
                   cwd=ctx.cfg.repo, mutating=True)
    return 0


def cmd_rm(ctx, args):
    runtime = _runtime(ctx)
    if args.all:
        result = ctx.runner.run(
            [runtime, "ps", "-aq", "--filter", "name=%s" % _prefix(ctx)],
            cwd=ctx.cfg.repo, capture=True, check=False)
        ids = [l.strip() for l in (result.stdout or "").splitlines() if l.strip()]
        if not ids:
            ctx.ui.say("no sandboxes to remove")
            return 0
        argv = [runtime, "rm", "-f"] + ids
    elif args.name:
        argv = [runtime, "rm", "-f", args.name]
    else:
        raise ZixError("give a sandbox name or --all")
    ctx.runner.run(argv, cwd=ctx.cfg.repo, mutating=True)
    return 0
