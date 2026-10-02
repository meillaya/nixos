"""Thin wrappers around the external tools zix exposes.

Each tool is configured in zix.json under ``tools.<name>`` as a command
prefix (``"command": ["nix", "run", "...", "--"]``). zix never re-implements
them; it adds environment checks, sensible defaults, and the repo's own
paths where relevant.
"""

from .util import ZixError


def tool_command(cfg, name):
    tool = cfg.tool(name)
    command = tool.get("command")
    if not command:
        raise ZixError("tool %r has no command configured" % name)
    return list(command)


def run_tool(ctx, name, extra, mutating=True, capture=False, check=False):
    argv = tool_command(ctx.cfg, name) + list(extra)
    return ctx.runner.run(argv, cwd=ctx.cfg.repo, mutating=mutating,
                          capture=capture, check=check)


def require_program(program, hint=None):
    import shutil
    if shutil.which(program) is None:
        raise ZixError(
            "%s is not on PATH%s" % (program, (": " + hint) if hint else ""))
