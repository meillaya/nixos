"""Backups for every file zix rewrites.

Before a mutating operation, the files it may touch are copied under
``zix/backups/<timestamp>-<label>/`` with a ``meta.json`` recording what was
copied. If an operation fails half-way (parse check, flake lock, verify), zix
restores the snapshot so the repo is never left in a broken in-between state.

Git is the real history; this is the crash net for the working tree.
"""

import json
import shutil
from pathlib import Path

from .util import now_stamp, relpath

KEEP = 20  # snapshots retained


class Snapshot:
    def __init__(self, directory, files):
        self.directory = Path(directory)
        self.files = list(files)

    def restore(self):
        for original, stored in self.files:
            shutil.copy2(stored, original)


class Backups:
    def __init__(self, repo, ui):
        self.repo = Path(repo)
        self.ui = ui
        self.root = self.repo / "zix" / "backups"

    def snapshot(self, files, label):
        """Copy ``files`` (repo-relative or absolute paths) aside.

        Files that do not exist yet are remembered as 'absent' so restore can
        delete them again (rolling back a creation).
        """
        directory = self.root / ("%s-%s" % (now_stamp(), label))
        directory.mkdir(parents=True, exist_ok=True)
        stored = []
        meta = {"label": label, "files": []}
        for path in files:
            path = Path(path)
            rel = relpath(path, self.repo)
            entry = {"path": rel, "existed": path.exists()}
            if path.exists():
                target = directory / rel
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path, target)
                entry["stored"] = str(target.relative_to(directory))
            meta["files"].append(entry)
            stored.append((path, entry))
        (directory / "meta.json").write_text(
            json.dumps(meta, indent=2, sort_keys=True) + "\n")
        self._prune()
        return Snapshot(
            directory,
            [(Path(self.repo) / e["path"],
              (directory / e["stored"]) if e.get("stored") else None)
             for e in meta["files"]]
        )

    def restore(self, snapshot):
        for original, stored in snapshot.files:
            if stored is not None and stored.exists():
                original.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(stored, original)
            elif original.exists():
                # Path was created by the failed operation; drop it again.
                original.unlink()

    def _prune(self):
        if not self.root.exists():
            return
        snapshots = sorted([d for d in self.root.iterdir() if d.is_dir()])
        for old in snapshots[:-KEEP]:
            shutil.rmtree(old, ignore_errors=True)
