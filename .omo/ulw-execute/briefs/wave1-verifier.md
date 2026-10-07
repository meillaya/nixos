# Wave-1 independent adversarial verifier — plan `thinkpad-zero-touch-install`

You are the INDEPENDENT VERIFIER for wave 1. You did not implement any of this work.
Your job: adversarially verify the wave-1 checkboxes (todos 1, 2, 3, 4, 5, 12) against
the plan's acceptance criteria and return a per-todo verdict. A worker's DoneClaim is
NEVER taken at face value; `confirmed` is the only pass verdict.

## Sources of truth
- Plan: `/home/mei/nixos/.omo/plans/thinkpad-zero-touch-install.md` (read it fully).
- Worktree under verification: `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave1` (branch `thinkpad-zero-touch-install/wave1`).
- Expected tip at dispatch: `4897953` ; full: `4897953233b767c47d826a6f4cd97db34b936a38`.
  If HEAD has moved or the tree is dirty when you start, note it, verify at the CURRENT
  tip, and report exactly which commits you verified. Never fix anything — report only.
- Worker evidence so far (read them, but they are claims, not proof):
  `/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/task-{1,2,3,4,5,12}-*`

## Verified commits claimed (main..HEAD order)
```
4897953 test(install): give the mutations check a writable sandbox HOME
bc05cb4 feat(iso): btrfs/vfat support and boot-loaded btrfs module
5688845 fix(iso): land the enrollment base record declaratively
bde4937 test(install): restore the bootstrap-password mutation coverage
ceca3a7 feat(install): shared staging builder for the password and payload
bb696d1 feat(install): put mkpasswd on the installer PATH
18fc43e feat(install): forward --extra-files/--chown and record the destructive attempt
```

## Method — per todo
For EACH of todos 1, 2, 3, 4, 5, 12:
1. Read the plan's section for that todo (verbatim acceptance criteria + QA scenarios).
2. Run the ACCEPTANCE CRITERIA commands yourself in the worktree (adapt `/home/mei/nixos`
   -> `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave1` where the command evaluates the flake). Wrap nix commands in `timeout 900`,
   capture full output.
3. Run the QA scenarios: where a failure/destructive variant is described (stub failing
   `mkpasswd`, missing flag args, token removal in a SCRATCH COPY under /tmp), run it and
   show it fails as described; never mutate the worktree's real files.
4. Inspect the commit itself: `git show --stat <hash>` — it must contain exactly the todo's
   files; `git show <hash>` must contain no plaintext password, no staging tmpdir, no
   `.direnv`, no `.omo` product edits.
5. Adversarial probes you MUST cover explicitly (results per probe):
   - `stale_state`: each decisive eval/script run TWICE; results identical; new content is
     what the eval reflects (e.g. the etc text, the btrfs attrs, the mkpasswd path).
   - `dirty_worktree`: tree clean at tip; per-commit file lists exactly match the plan.
   - `misleading_success_output`: `--dry-run` prints no secret; the `|| true` masking in
     the ISO auto-enroll keeps its journal-visible failure marker; the t12 check script
     FAILS when its pinned token is removed (scratch copy); no test passes by construction.
   - report the other classes as `n/a — <reason>` when their trigger facts do not hold.
6. Where a claimed test depends on another lane's file (e.g. t5's failure scenario needing
   the t3 helper), re-run that combined check now that ALL wave-1 files exist.

## Required output (write to file AND end your message with it)
Write `/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/wave1-verification.json`:
```json
{"verified_tip": "<full sha>", "verified_at": "<iso8601>",
  "todos": {
    "1":  {"verdict": "confirmed|false-positive|needs-fix|needs-human-review", "evidence": ["cmd => observed"], "repro": "...", "confidence": 0.0},
    "2":  {...}, "3": {...}, "4": {...}, "5": {...}, "12": {...}
  },
  "adversarial": {"stale_state": "...", "dirty_worktree": "...", "misleading_success_output": "...", "other": "..."},
  "drift": "none | describe any tip move",
  "cleanup": ["scratch dirs removed / none created"]}
```

## Rules
- Do NOT edit any product file, do NOT commit, do NOT push. Read-only on the worktree.
- Scratch copies only under `/tmp/...`, and delete them when done (record the receipt).
- Be adversarial: try to falsify each claim. If you cannot reproduce a claim, that is a
  `needs-fix` or `needs-human-review` verdict, never a shrug. If a claim reproduces, cite
  the exact command + observed output.
- Report the verdicts in your final message too (concise), plus your confidence per todo.
