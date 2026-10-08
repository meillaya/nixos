"""zix - config and profile manager for Nix configurations.

Entry point: `zix --help`, or `python3 tools/zix/cli.py --help` from a
checkout, or `nix run github:<owner>/<repo>?dir=tools/zix -- --help`. Every
repository-specific detail comes from the nearest zix.json, so one binary
serves any configuration that ships a manifest.
"""

import argparse
import os
import sys
from pathlib import Path

from zixlib import cmd_get, cmd_misc, cmd_pkg, cmd_sandbox, cmd_vm
from zixlib.backups import Backups
from zixlib.config import Config, discover_repo, load_config
from zixlib.runner import Runner
from zixlib.util import UI, ZixError

VERSION = "0.2.0"

# Commands that work without a zix.json: they touch nothing in a repository.
REPO_OPTIONAL = {"get"}

EPILOG = """\
examples:
  zix doctor                             environment and repo sanity
  zix get ripgrep                        install a package into the user profile now
  zix get hello@2.10                     an exact nixpkgs version, no repo needed
  zix add ripgrep                        add to the zix-managed set (all hosts)
  zix add kitty --target linux           add to a curated list named in zix.json
  zix add jq@1.7.1                       pin an exact version via nixpkgs-multiverse
  zix rm jq                              remove everywhere (pin included)
  zix unpin jq                           follow nixpkgs again
  zix list                               managed packages and pins
  zix where htop                         locate a declaration
  zix search ripgrep                     search nixpkgs (stable and unstable)
  zix flakes list sops                   search the omniflake index
  zix sandbox run --agent claude         disposable agent sandbox (omnibin image)
  zix follows check                      dedupe audit via nix-auto-follow
  zix check                              run the repo's check suite
  zix switch [HOST]                      apply (default host comes from zix.json)

`zix pkg <verb>` is the long form of every package verb above and keeps working.

global flags:
  --dry-run prints intended file edits and skips state-changing commands.
  --repo points at a configuration that ships a zix.json.
"""


class Ctx:
    def __init__(self, repo, cfg, ui, runner, dry_run, json_out):
        self.repo = repo
        self.cfg = cfg
        self.ui = ui
        self.runner = runner
        self.dry_run = dry_run
        self.json_out = json_out
        self.backups = Backups(repo, ui)


def _strip(seq):
    if not isinstance(seq, (list, tuple)):
        return seq
    seq = list(seq or [])
    if seq and seq[0] == "--":
        seq = seq[1:]
    return seq


def _register_package_verbs(parent, skip=frozenset()):
    """Register the package verbs on `parent`.

    Both `zix pkg <verb>` and the bare `zix <verb>` aliases come from here, so
    the two surfaces cannot drift apart. `skip` names the verbs the caller
    already owns; the top level keeps `update` for the flake-input refresh.
    """

    def span(name, help_text):
        if name in skip:
            return None
        return parent.add_parser(name, help=help_text)

    add = span("add", "add a package, optionally pinned to a version")
    if add is not None:
        add.add_argument("specs", nargs="+", metavar="NAME[@VERSION]")
        add.add_argument("--target", help="a target named in zix.json "
                         "(default: the manifest's default_target)")
        add.add_argument("--skip-check", action="store_true",
                         help="skip the multiverse version-existence check")
        add.add_argument("--no-verify", action="store_true",
                         help="skip the post-pin evaluation check")

    rm = span("rm", "remove a package from every declaration")
    if rm is not None:
        rm.add_argument("names", nargs="+")
        rm.add_argument("--target", help="restrict removal to one target")
        rm.add_argument("--all", action="store_true",
                        help="remove from every target without asking")

    unpin = span("unpin", "stop pinning; follow nixpkgs again")
    if unpin is not None:
        unpin.add_argument("names", nargs="+")

    span("list", "list managed packages and pins")
    span("ls", "alias of list")

    where = span("where", "locate a declaration")
    if where is not None:
        where.add_argument("name")

    search = span("search", "search nixpkgs (stable+unstable)")
    if search is not None:
        search.add_argument("query")
        search.add_argument("--limit", type=int, default=15)

    versions = span("versions", "version history via multiverse")
    if versions is not None:
        versions.add_argument("name")

    update = span("update", "report / move pins to latest")
    if update is not None:
        update.add_argument("names", nargs="*")
        update.add_argument("--apply", action="store_true")
        update.add_argument("--no-verify", action="store_true")


def build_parser():
    parser = argparse.ArgumentParser(
        prog="zix",
        description="Manage packages, pins, sandboxes and VMs for this Nix config.",
        epilog=EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--repo", help="path to the repo (default: nearest "
                        "zix.json upwards from the current directory)")
    parser.add_argument("--dry-run", action="store_true",
                        help="print intended changes; make none")
    parser.add_argument("--json", action="store_true",
                        help="machine-readable output where supported")
    parser.add_argument("--no-color", action="store_true")
    parser.add_argument("-q", "--quiet", action="store_true")
    parser.add_argument("--version", action="version",
                        version="zix " + VERSION)
    sub = parser.add_subparsers(dest="command", metavar="COMMAND")

    sub.add_parser("doctor", help="check environment, repo and tools")

    check = sub.add_parser("check", help="run the repo's check suite")
    check.add_argument("--full", action="store_true",
                       help="also run the expensive full check")

    get = sub.add_parser("get", help="install NAME[@VERSION] into a nix "
                              "profile now (runtime; no repo needed)")
    get.add_argument("specs", nargs="*", metavar="NAME[@VERSION]")
    get.add_argument("--attr", help="nixpkgs attribute when it differs from NAME")
    get.add_argument("--profile", help="profile to write (default: the user profile)")
    get.add_argument("--eval-road", action="store_true",
                     help="resolve by evaluating nixpkgs instead of the "
                          "multiverse store-path index")
    get.add_argument("--force", action="store_true",
                     help="reinstall when the profile already has NAME")
    get.add_argument("--list", action="store_true",
                     help="list what the profile currently holds")

    switch = sub.add_parser("switch", help="build and activate a host")
    switch.add_argument("host", nargs="?", help="host name (default: from zix.json)")
    switch.add_argument("extra", nargs=argparse.REMAINDER)

    update = sub.add_parser("update", help="refresh flake inputs (repo update app)")
    update.add_argument("extra", nargs=argparse.REMAINDER)

    follows = sub.add_parser("follows", help="nix-auto-follow: dedupe audit / fix")
    follows_sub = follows.add_subparsers(dest="follows_cmd", metavar="{check,fix}")
    follows_sub.add_parser("check", help="check mode (exit 1 when not deduped)")
    follows_sub.add_parser("fix", help="rewrite flake.lock in place (backed up)")

    flakes = sub.add_parser("flakes", help="omniflake: thousands of flakes, one input")
    flakes_sub = flakes.add_subparsers(dest="flakes_cmd", metavar="{list,run}")
    flakes_list = flakes_sub.add_parser("list", help="search the flake index")
    flakes_list.add_argument("--match", help="substring filter")
    flakes_list.add_argument("--limit", type=int, default=40)
    flakes_run = flakes_sub.add_parser("run", help="run a package from an indexed flake")
    flakes_run.add_argument("name", help="flake name (bare or qualified)")
    flakes_run.add_argument("--attr", help="attribute path (default packages.<system>.default)")
    flakes_run.add_argument("--pinned", action="store_true",
                            help="use the flake author's own pins")
    flakes_run.add_argument("extra", nargs=argparse.REMAINDER)

    pkg = sub.add_parser("pkg", help="add / remove / pin packages")
    pkg_sub = pkg.add_subparsers(dest="pkg_cmd", metavar="SUBCOMMAND")
    _register_package_verbs(pkg_sub)

    # Bare aliases: `zix add` is `zix pkg add`. The top-level `update` stays the
    # flake-input refresh, so the package verb of that name is skipped here.
    _register_package_verbs(sub, skip=frozenset({"update"}))

    grail = sub.add_parser("grail", help="version ranges over nixpkgs history (passthrough)")
    grail.add_argument("args", nargs=argparse.REMAINDER)

    binp = sub.add_parser("bin", help="omnibin: every binary nixpkgs ever shipped")
    binp.add_argument("args", nargs=argparse.REMAINDER)

    wrap = sub.add_parser("wrap", help="wrap-buddy: patch a prebuilt ELF for NixOS")
    wrap.add_argument("args", nargs=argparse.REMAINDER)

    vm = sub.add_parser("vm", help="rewindvm: deterministic disposable VMs (passthrough)")
    vm.add_argument("args", nargs=argparse.REMAINDER)

    sandbox = sub.add_parser("sandbox", help="disposable container sandboxes")
    sandbox_sub = sandbox.add_subparsers(dest="sandbox_cmd", metavar="SUBCOMMAND")
    sandbox_run = sandbox_sub.add_parser("run", help="start a sandbox")
    sandbox_run.add_argument("--image")
    sandbox_run.add_argument("--name")
    sandbox_run.add_argument("--workspace", help="directory to mount (default: cwd)")
    sandbox_run.add_argument("--agent", help="mount an agent's config dirs")
    sandbox_run.add_argument("--detach", action="store_true")
    sandbox_run.add_argument("--keep", action="store_true",
                             help="keep the container after exit")
    sandbox_run.add_argument("cmds", nargs=argparse.REMAINDER, metavar="CMD")
    sandbox_ls = sandbox_sub.add_parser("ls", help="list sandboxes")
    sandbox_ls.add_argument("-a", "--all", action="store_true")
    sandbox_exec = sandbox_sub.add_parser("exec", help="exec into a sandbox")
    sandbox_exec.add_argument("name", nargs="?")
    sandbox_exec.add_argument("cmds", nargs=argparse.REMAINDER, metavar="CMD")
    sandbox_rm = sandbox_sub.add_parser("rm", help="remove a sandbox")
    sandbox_rm.add_argument("name", nargs="?")
    sandbox_rm.add_argument("--all", action="store_true")

    inp = sub.add_parser("input", help="manage flake inputs")
    inp_sub = inp.add_subparsers(dest="input_cmd", metavar="{ls,add,remove}")
    inp_sub.add_parser("ls", help="list inputs")
    inp_add = inp_sub.add_parser("add", help="add an input and lock")
    inp_add.add_argument("name")
    inp_add.add_argument("--url", required=True)
    inp_add.add_argument("--follows", action="append",
                         help="path=name (repeatable), e.g. inputs.nixpkgs.follows=nixpkgs")
    inp_rm = inp_sub.add_parser("remove", help="remove an input and lock")
    inp_rm.add_argument("name")

    return parser


HANDLERS = {
    "doctor": cmd_misc.cmd_doctor,
    "get": cmd_get.cmd_get,
    "check": cmd_misc.cmd_check,
    "switch": cmd_misc.cmd_switch,
    "update": cmd_misc.cmd_update,
    "follows.check": cmd_misc.cmd_follows_check,
    "follows.fix": cmd_misc.cmd_follows_fix,
    "flakes.list": cmd_misc.cmd_flakes_list,
    "flakes.run": cmd_misc.cmd_flakes_run,
    "grail": cmd_misc.cmd_grail,
    "bin": cmd_misc.cmd_bin,
    "wrap": cmd_misc.cmd_wrap,
    "input.ls": cmd_misc.cmd_input_ls,
    "input.add": cmd_misc.cmd_input_add,
    "input.remove": cmd_misc.cmd_input_remove,
    "pkg.add": cmd_pkg.cmd_add,
    "pkg.rm": cmd_pkg.cmd_rm,
    "pkg.unpin": cmd_pkg.cmd_unpin,
    "pkg.list": cmd_pkg.cmd_list,
    "pkg.ls": cmd_pkg.cmd_list,
    "pkg.where": cmd_pkg.cmd_where,
    "pkg.search": cmd_pkg.cmd_search,
    "pkg.versions": cmd_pkg.cmd_versions,
    "pkg.update": cmd_pkg.cmd_update,
    # Bare aliases for the package verbs, from _register_package_verbs.
    "add": cmd_pkg.cmd_add,
    "rm": cmd_pkg.cmd_rm,
    "unpin": cmd_pkg.cmd_unpin,
    "list": cmd_pkg.cmd_list,
    "ls": cmd_pkg.cmd_list,
    "where": cmd_pkg.cmd_where,
    "search": cmd_pkg.cmd_search,
    "versions": cmd_pkg.cmd_versions,
    "sandbox.run": cmd_sandbox.cmd_run,
    "sandbox.ls": cmd_sandbox.cmd_ls,
    "sandbox.exec": cmd_sandbox.cmd_exec,
    "sandbox.rm": cmd_sandbox.cmd_rm,
    "vm": cmd_vm.cmd_vm,
}


def main(argv=None):
    parser = build_parser()
    args = parser.parse_args(argv)
    ui = UI(color=(False if args.no_color else None), quiet=args.quiet)

    if not args.command:
        parser.print_help()
        return 0

    for attr in ("args", "extra", "cmds"):
        if hasattr(args, attr):
            setattr(args, attr, _strip(getattr(args, attr)))

    sub = getattr(args, args.command + "_cmd", None)
    key = args.command if sub is None else "%s.%s" % (args.command, sub)
    handler = HANDLERS.get(key)
    if handler is None:
        ui.error("missing or unknown subcommand: %s (see `zix %s --help`)"
                 % (key, args.command))
        return 2

    try:
        try:
            repo = discover_repo(explicit=args.repo)
            cfg = load_config(repo)
        except ZixError:
            if key not in REPO_OPTIONAL or args.repo:
                raise
            repo = Path.cwd()
            cfg = Config(repo, {"version": 1})
            ui.note("no zix.json found upwards; `%s` does not need a repository"
                    % key)
        ctx = Ctx(repo, cfg, ui, Runner(ui, args.dry_run), args.dry_run,
                  args.json)
        return handler(ctx, args) or 0
    except ZixError as exc:
        ui.error(str(exc))
        return exc.exit_code
    except KeyboardInterrupt:
        ui.error("interrupted")
        return 130


if __name__ == "__main__":
    sys.exit(main())
