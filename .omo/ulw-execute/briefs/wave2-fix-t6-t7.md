# Wave-2 FIX brief — t6/t7 `--chown` on a missing identity subtree

An independent verifier found a real defect at tip c85a8ff in the wave-2 worktree.
You are the fix executor. Work ONLY in `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave2`.

## The finding (verifier, confidence 0.8)
`install_phase` in `apps/x86_64-linux/install` forwards
`--chown home/<user>/.config <uid>:<gid>` UNCONDITIONALLY whenever `install_user`
resolves — even when `stage_age_identity` warns "no age identity" and stages NO
`home/` subtree. nixos-anywhere (`src/nixos-anywhere.sh`, `set -euo pipefail`) runs
`printf ... | pr -2t | runSsh 'while read file ownership; do chown -R "$ownership" "/mnt/$file"; done'`
with no `|| true`; `chown -R` on the missing path fails (rc=1). `runDisko` (format)
runs BEFORE the install phase — so on a target lacking the age key the one-command
installer can FORMAT THE DISK and then ABORT before installing a system.
Repro: a no-key staged run still forwards `--chown` while the stage has no `home/` tree.

## Required fix (minimal, targeted)
1. In `apps/x86_64-linux/install`, forward `--chown home/<user>/.config <uid>:<gid>`
   ONLY when the `.config` subtree was actually staged (e.g. track the staging result
   and/or test the staged path exists in the stage). When no identity was staged,
   forward `--extra-files` WITHOUT any `--chown`.
2. Keep the plan's warn-and-continue policy for a missing key (do NOT die; do NOT
   change `staging_identity`'s contract or `bin/_install-staging.sh`).
3. `--install-only` still forwards no staging flags; the dry-run plan must reflect the
   conditional truthfully (print the `--chown` only when it would be forwarded).
4. Do NOT touch any other file; do NOT touch `bin/host-install.sh` (t15 is verified safe:
   it forwards `--chown` only with `--stage-identity`).

## Verification you must run (and capture)
- BEFORE the fix: reproduce the defect in a scratch copy / harness (no-key run forwards
  `--chown`; the chown pipeline fails rc=1 on the missing path). Capture it.
- AFTER the fix: same scenario shows NO `--chown` forwarded, the stage tree still carries
  the other artifacts, and the run completes rc=0; the identity-present scenario STILL
  forwards the exact `--chown home/mei/.config 1000:100`.
- `bash -n apps/x86_64-linux/install`; `bash tests/dendritic-apps.sh`;
  `./apps/x86_64-linux/install --dry-run` (both with and without a key available) shows
  the conditional `--chown` truthfully.
- Never run repo-mutating harnesses against the real worktree — scratch copies under /tmp only.
- Evidence: `/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/task-6-7-fix-thinkpad-zero-touch-install.log`.

## Commit
One commit, exact message: `fix(install): forward --chown only when the identity subtree is staged`
`git add` only `apps/x86_64-linux/install`.

## DoneClaim (end your message with it)
`DoneClaim: {"task": "t6/t7 fix: conditional --chown", "changed_files": [...], "tests": ["<cmd> => <result>"], "manual_qa": ["<evidence path>"], "cleanup": ["..."], "risks": [...]}`
