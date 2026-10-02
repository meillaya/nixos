"""Editing the repo's Nix files.

Two editing styles, both conservative:

* Package list files (``modules/*/packages.nix``): entries live between
  ``# BEGIN zix`` / ``# END zix`` markers. zix creates the marker block on
  first use by appending a ``++ [ ... ]`` section. Insertion only ever writes
  a bare line inside the block; removal matches whole lines
  (``[pkgs.]<name>`` alone on a line) so expressions and one-liners are never
  touched.

* flake.nix inputs: flat ``name.url = "...";`` and
  ``name.inputs.<path>.follows = "...";`` entries. Block-style inputs
  (``name = { ... };``) are read but never rewritten.

Every mutation is followed by ``nix-instantiate --parse`` on the file and the
caller rolls back from its backup snapshot on failure.
"""

import difflib
import re

from .util import ZixError

MARK_BEGIN = "# BEGIN zix: entries managed by `nix run .#zix -- pkg ...` - do not edit by hand"
MARK_END = "# END zix"


# -- package list files ------------------------------------------------------

def ensure_markers(text):
    if MARK_BEGIN in text and MARK_END in text:
        return text
    if not text.endswith("\n"):
        text += "\n"
    return text + "\n++ [\n  %s\n  %s\n]\n" % (MARK_BEGIN, MARK_END)


def token_lines(text, token):
    """Line numbers (0-based) of whole-line declarations of ``token``."""
    pattern = re.compile(r"^\s*(?:pkgs\.)?%s\s*$" % re.escape(token))
    return [i for i, line in enumerate(text.split("\n")) if pattern.match(line)]


def insert_token(text, token):
    """Insert ``token`` into the marker block. Returns (text, added)."""
    text = ensure_markers(text)
    lines = text.split("\n")
    begin = lines.index("  " + MARK_BEGIN)
    end = lines.index("  " + MARK_END)
    for line in lines[begin + 1:end]:
        if line.strip() in (token, "pkgs." + token):
            return text, False
    lines.insert(end, "  " + token)
    return "\n".join(lines), True


def remove_token(text, token):
    """Remove every whole-line declaration of ``token``. Returns (text, n)."""
    pattern = re.compile(r"^\s*(?:pkgs\.)?%s\s*$" % re.escape(token))
    kept, removed = [], 0
    for line in text.split("\n"):
        if pattern.match(line):
            removed += 1
        else:
            kept.append(line)
    return "\n".join(kept), removed


# -- flake.nix inputs --------------------------------------------------------

INPUT_RE = re.compile(r"^    ([A-Za-z0-9_-]+)(\.|\s*=)")


def inputs_block(text):
    lines = text.split("\n")
    start = None
    for i, line in enumerate(lines):
        if re.match(r"^\s*inputs\s*=\s*\{\s*$", line):
            start = i
            break
    if start is None:
        raise ZixError("could not find the `inputs = {` block in flake.nix")
    for j in range(start + 1, len(lines)):
        if re.match(r"^  \};\s*$", lines[j]):
            return lines, start, j
    raise ZixError("could not find the end of the inputs block in flake.nix")


def input_names(text):
    lines, start, end = inputs_block(text)
    seen = []
    for line in lines[start + 1:end]:
        match = INPUT_RE.match(line)
        if match and match.group(1) not in seen:
            seen.append(match.group(1))
    return seen


def has_input(text, name):
    return name in input_names(text)


def input_url(text, name):
    lines, start, end = inputs_block(text)
    block = "\n".join(lines[start:end])
    match = re.search(
        r"^\s*%s\.url\s*=\s*\"([^\"]+)\"" % re.escape(name), block, re.M)
    if match:
        return match.group(1)
    # Block style: `name = { url = "..."; ... };` - the url is one level in.
    block_lines = lines[start + 1:end]
    for index, line in enumerate(block_lines):
        if not re.match(r"^    %s\s*=\s*\{\s*$" % re.escape(name), line):
            continue
        for follow in block_lines[index + 1:]:
            if re.match(r"^    \S", follow):
                break
            url = re.search(r"\burl\s*=\s*\"([^\"]+)\"", follow)
            if url:
                return url.group(1)
        return None
    return None


def add_input(text, name, url, follows=None):
    follows = follows or {}
    lines, start, end = inputs_block(text)
    # Refuse duplicates up front (caller checks, but keep the edit honest).
    if name in input_names(text):
        return text, False
    added = ['', '    %s.url = "%s";' % (name, url)]
    for path, target in follows.items():
        added.append('    %s.inputs.%s.follows = "%s";' % (name, path, target))
    lines[end:end] = added
    return "\n".join(lines), True


def remove_input(text, name):
    lines, start, end = inputs_block(text)
    pattern = re.compile(r"^\s*%s(\.|\s*=)" % re.escape(name))
    block = lines[start + 1:end]
    if any(re.match(r"^\s*%s\s*=\s*\{\s*$" % re.escape(name), line)
           for line in block):
        raise ZixError(
            "input %r is a block declaration; remove it by hand" % name)
    kept, removed = [], 0
    for line in lines:
        if pattern.match(line):
            removed += 1
        else:
            kept.append(line)
    return "\n".join(kept), removed


# -- shared helpers ----------------------------------------------------------

def write_text(path, text):
    if not text.endswith("\n"):
        text += "\n"
    path.write_text(text)


def validate_nix(runner, path, mutating=True):
    """Parse a nix file; raises ZixError when the syntax is broken."""
    runner.run(["nix-instantiate", "--parse", str(path)],
               check=True, capture=True, mutating=mutating)


def unified_diff(old, new, label_a, label_b):
    diff = difflib.unified_diff(
        old.splitlines(), new.splitlines(),
        fromfile=label_a, tofile=label_b, lineterm="")
    return "\n".join(diff)
