"""Subprocess execution. Every external command zix runs goes through here,
so dry-run mode and logging stay in one place.

``mutating=True`` marks commands that change state outside the repo working
tree (nix flake lock, nix run of an external tool, podman, ...). Under
``--dry-run`` those are printed instead of executed. Read-only commands
(nix eval, mvs queries, git status) still run during a dry run.
"""

import shlex
import subprocess

from .util import ZixError


class Result:
    def __init__(self, argv, returncode, stdout, stderr):
        self.argv = argv
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr


class Runner:
    def __init__(self, ui, dry_run=False):
        self.ui = ui
        self.dry_run = dry_run

    @staticmethod
    def show(argv):
        return " ".join(shlex.quote(a) for a in argv)

    def run(self, argv, cwd=None, check=True, capture=False, mutating=False,
            env=None, quiet=False):
        argv = [str(a) for a in argv]
        if mutating and self.dry_run:
            if not quiet:
                self.ui.note("[dry-run] would run: " + self.show(argv))
            return Result(argv, 0, "", "")
        if not quiet:
            self.ui.note("$ " + self.show(argv))
        proc = subprocess.run(
            argv,
            cwd=str(cwd) if cwd else None,
            text=True,
            capture_output=capture,
            env=env,
        )
        result = Result(argv, proc.returncode,
                        proc.stdout or "", proc.stderr or "")
        if check and proc.returncode != 0:
            detail = (result.stderr or result.stdout or "").strip()
            raise ZixError(
                "command failed (exit %d): %s\n%s"
                % (proc.returncode, self.show(argv), detail[-4000:])
            )
        return result
