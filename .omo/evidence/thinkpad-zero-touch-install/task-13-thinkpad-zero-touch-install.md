# task-13 — Docs (wave 3 lane C, plan `thinkpad-zero-touch-install`)

- Worktree: `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave3` (branch `thinkpad-zero-touch-install/wave3`)
- Base commit (waves 1-2 landed): `bf90e20`
- Commit produced: `ae0a3ef593a6efda94c74bef4d80fdf30a8138ff` `docs(install): document staging, the opt-in gate, and the rescue route`
- Files changed (exactly 4): `README.md`, `bin/AGENTS.md`, `docs/service-notes/new-machine-ssh-install.md`, `docs/service-notes/nixos-anywhere-iso-install.md`
- Closes: IS-6. Sibling-lane files (`modules/flake/checks.nix`, `tests/dendritic-apps.sh`, `tests/install-staging.sh`) were left staged and untouched.

## What was documented (all against the shipped code, re-read in this worktree)
- Staging: the install app (full path) and the operator entry point (`bin/host-install.sh`, not `--install-only`) mint a per-install password via `bin/_install-staging.sh`, stage the enrollment artifacts and the age identity, print the password once, and forward the tmpfs stage as `nixos-anywhere --extra-files` with `--chown home/<user>/.config <uid>:<gid>` only when the identity subtree was staged.
- `--save` downgrade: the artifacts persist in the installed system, so `--skip-fold` no longer requires `--save`; stale "requires `--save`" / "the app demands `--save`" text was replaced.
- Opt-in ISO autostart: append `nixos.autoinstall=1` at the boot menu (per boot); `nixos-autoinstall.service` runs the install app; a failure lands in `iso-install-rescue.target` (root shell on tty1); the flag is never in `boot.kernelParams`.
- Rescue route: `--rescue-identity` mounts the live btrfs `@home` read-only, copies `~/.config/sops/age/keys.txt` into the stage, dies when it cannot find it.
- New flags in `bin/AGENTS.md`: `--extra-files`, `--chown`, `--stage-identity`; plus the sourced helper's contract.
- Official minimal ISO limits restated: only the one-command app works (no `hardware-enroll` oneshot, no baked base declaration, no `nixos-autoinstall.service`).

## QA scenarios (happy + failure), exact invocations and observed results

### A1 — happy: acceptance grep 1
```
$ cd /home/mei/nixos-wt/thinkpad-zero-touch-install-wave3
$ grep -Fq -- '--extra-files' README.md docs/service-notes/*.md ; echo $?
0
PASS grepA exit=0
```

### A2 — happy: acceptance grep 2
```
$ grep -Fq 'nixos.autoinstall=1' docs/service-notes/nixos-anywhere-iso-install.md ; echo $?
0
PASS grepB exit=0
```

### A3 — misleading_success_output probe: every documented installer flag exists in code
```
### installer-scope flags (lines naming host-install.sh or the install app)
OK   --chown
OK   --dry-run
OK   --extra-files
OK   --install-only
OK   --save
OK   --skip-fold
OK   --skip-install
OK   --skip-verify
OK   --stage-identity
OK   --target-host
OK   --yes
A3b installer-flag missing-count=0
```
The remaining `--flag` tokens in the four docs belong to external tools or other `bin/` commands, unchanged by this work:
```
OK   --fixture present in bin/nix-config-hardware-collector (pre-existing)
OK   --hostname present in README.md (nh, external)
OK   --profile present in docs/service-notes/new-machine-ssh-install.md (nix profile, external)
OK   --all-systems / --no-build present in README.md (nix flake check, pre-existing)
OK   --strict / --expr / --eval present in README.md (nix-instantiate, pre-existing)
```

### A4 — failure: a flag that does not exist must not be documented
```
PASS --no-such-flag absent from docs (grep rc=1)
PASS code has no --no-such-flag
```
This proves the A3 grep class is falsifiable rather than a tautology.

### A5 — unit / target / kernel-flag names in the docs exist in the ISO module
```
OK   nixos-autoinstall.service
OK   iso-install-rescue.target
OK   nixos.autoinstall=1   (ConditionKernelCommandLine, NOT boot.kernelParams)
```

### A6 — the new behavior is present in all three prose files
```
README.md: 9 matches of (--extra-files|--stage-identity|--rescue-identity|nixos.autoinstall=1)
docs/service-notes/new-machine-ssh-install.md: 8 matches
docs/service-notes/nixos-anywhere-iso-install.md: 7 matches
```

## Commit / worktree probe (brief's `dirty_worktree`)
```
$ git show --stat --oneline HEAD
ae0a3ef docs(install): document staging, the opt-in gate, and the rescue route
 README.md                                        |  55 ++++++++++--
 bin/AGENTS.md                                    | 109 +++++++++++++++++++++++
 docs/service-notes/new-machine-ssh-install.md    |  42 +++++++--
 docs/service-notes/nixos-anywhere-iso-install.md |  57 ++++++++++--
 4 files changed, 237 insertions(+), 26 deletions(-)
```
Only the four intended files land in HEAD; the sibling lanes' staged files (`modules/flake/checks.nix`, `tests/dendritic-apps.sh`, `tests/install-staging.sh`) remain staged and uncommitted by this lane.

## Deviations / notes
- `bin/AGENTS.md` is git-excluded by `/home/mei/nixos/.git/info/exclude` (managed omo init-deep block, pattern `AGENTS.md`) and is untracked in every commit; it is also absent from a fresh worktree because worktrees check out only tracked files. The plan's commit probe expects it in HEAD, so it was materialised and committed with `git add -f bin/AGENTS.md`. Every other `AGENTS.md` remains local-only.
- No resource was spawned by any scenario: no server, tmux session, browser, container, port, or temp file outside the git worktree. Cleanup receipt: none needed.
- No `--dry-run`/`nix build` was run for this lane: the change set is prose only, so the greps plus the flag-exists probe are the proof; no shell file changed, so `bash -n` does not apply.
