"""`zix vm` - disposable / replayable Linux VMs through rewindvm.

rewindvm runs a build, a test suite or any command inside a KVM VM whose runs
are deterministic; you can replay, scrub and fork them. zix does not wrap the
subcommands - they are passed through verbatim so every rewind feature works -
but it checks the machine can run them and routes through the configured
flake ref.

Examples:
    zix vm check github:me/myflake#checks.x86_64-linux.default
    zix vm run --root ./rootfs -- make test
    zix vm ls
    zix vm replay <run>
"""

import os

from . import tools
from .util import ZixError


def cmd_vm(ctx, args):
    extra = list(args.args or [])
    if not extra:
        extra = ["--help"]
    if os.path.exists("/dev/kvm"):
        if not os.access("/dev/kvm", os.R_OK | os.W_OK):
            ctx.ui.warn("/dev/kvm exists but is not readable+writable by you")
    else:
        ctx.ui.warn(
            "no /dev/kvm: rewindvm needs KVM (guest CPU on bare metal); "
            "this machine cannot run it")
    tools.run_tool(ctx, "rewind", extra)
