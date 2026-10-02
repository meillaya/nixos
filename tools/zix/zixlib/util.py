"""Shared helpers for zix: output, errors, small parsing utilities."""

import os
import re
import sys
import datetime


class ZixError(Exception):
    """Fatal, user-facing error. The CLI prints the message and exits."""

    def __init__(self, message, exit_code=1):
        super().__init__(message)
        self.exit_code = exit_code


class UI:
    """Console output. Honors NO_COLOR and non-tty output."""

    def __init__(self, color=None, quiet=False):
        if color is None:
            color = sys.stdout.isatty() and os.environ.get("NO_COLOR") is None
        self.color = color
        self.quiet = quiet

    def _style(self, code, text):
        if not self.color:
            return text
        return "\033[%sm%s\033[0m" % (code, text)

    def bold(self, text):
        return self._style("1", text)

    def dim(self, text):
        return self._style("2", text)

    def green(self, text):
        return self._style("32", text)

    def yellow(self, text):
        return self._style("33", text)

    def red(self, text):
        return self._style("31", text)

    def say(self, msg=""):
        if not self.quiet:
            print(msg)

    def head(self, msg):
        if not self.quiet:
            print(self.bold(msg))

    def step(self, msg):
        if not self.quiet:
            print(self.dim("==> " + msg))

    def ok(self, msg):
        if not self.quiet:
            print(self.green("ok: ") + msg)

    def warn(self, msg):
        print(self.yellow("warning: ") + msg, file=sys.stderr)

    def error(self, msg):
        print(self.red("error: ") + msg, file=sys.stderr)

    def note(self, msg):
        if not self.quiet:
            print(self.dim(msg))


NAME_RE = re.compile(r"^[A-Za-z0-9_+.][A-Za-z0-9_+.-]*$")


def valid_name(name):
    return bool(NAME_RE.match(name))


def parse_spec(spec):
    """Split ``name`` or ``name@version`` into (name, version-or-None)."""
    if "@" in spec:
        name, _, version = spec.partition("@")
        version = version or None
        return name, version
    return spec, None


def now_stamp():
    return datetime.datetime.now().strftime("%Y%m%d-%H%M%S")


def iso_date():
    return datetime.date.today().isoformat()


def relpath(path, repo):
    try:
        return str(os.path.relpath(path, str(repo)))
    except ValueError:
        return str(path)
