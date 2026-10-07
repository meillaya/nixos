# Wave-2 independent adversarial verifier — plan `thinkpad-zero-touch-install`

You are the INDEPENDENT VERIFIER for wave 2 (todos 6, 7, 8, 9, 15). You did not implement
any of this work. A worker's DoneClaim is NEVER taken at face value; `confirmed` is the
only pass verdict.

## Sources of truth
- Plan: `/home/mei/nixos/.omo/plans/thinkpad-zero-touch-install.md` (read it fully).
- Worktree under verification: `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave2` (branch `thinkpad-zero-touch-install/wave2`).
- Record the tip (`git rev-parse HEAD`) at start; if it moves, note it and verify at the
  CURRENT tip reporting which commits you verified. Never fix anything — report only.
- Worker evidence: `/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/task-{6,7,8,9,15}-*`.

## Verified commits claimed (main..HEAD order)
```
c85a8ff feat(iso): opt-in gated auto-install with a rescue target
a55e272 feat(install): rescue the live age identity and verify host/disk bindings
c1bc2ea feat(install): persist artifacts and the age identity into the target
eca7ddc feat(install): mint and stage the password on the operator path
f9d3265 feat(install): generate and stage the per-install password
```

## Method — per todo
For EACH of todos 6, 7, 8, 9, 15:
1. Read the plan's section (verbatim acceptance criteria + QA scenarios).
2. Re-run the ACCEPTANCE commands in the worktree (adapt `/home/mei/nixos` -> `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave2` in
   flake evals; wrap nix in `timeout 900`; capture full output).
3. Re-run the QA scenarios (happy + the described failure variant) yourself; destructive
   variants only in SCRATCH COPIES under /tmp — never mutate the worktree.
4. `git show --stat <hash>` per commit: exactly the todo's files; no plaintext password,
   no staging tmpdir, no `.direnv`, no `.omo` product edits.
5. Adversarial probes (explicit results):
   - `stale_state`: decisive evals/scripts run TWICE; new content reflected; stages fresh.
   - `dirty_worktree`: tree clean at tip; per-commit file lists match the plan.
   - `misleading_success_output`: `--dry-run` prints no secret; the t9 unit has NO `|| true`
     and its failure path lands in the rescue target; staging counts ('password for' printed
     exactly once in apps/x86_64-linux/install); t15 `--install-only` prints no staging step.
   - `malformed_input`: stub-failing `mkpasswd` paths die before any transport call; missing
     `--stage-identity` SRC dies; a host/DMI mismatch dies before any wipe.
   - report other classes `n/a — <reason>` when triggers do not hold.
6. Cross-wave note: todo 9's acceptance references the eval wall of todo 11, which only
   arrives in wave 3. Verify the EQUIVALENT assertions directly at this tip: the unit's
   `wantedBy/wants/after/ConditionKernelCommandLine/ConditionPathExists/SuccessAction/
   OnFailure/Type/RemainAfterExit/StandardOutput`, the script referencing the app wrapper,
   `flake.isoConfig` exposed and `flake.iso` built from it, and the NEGATIVE check that
   `nixos.autoinstall=1` is NOT in `boot.kernelParams`. Note in your report that the formal
   wall lands later.


## Wave-2 special notes
- INCIDENT (already repaired by the orchestrator, must be re-probed): an early T15 e2e harness ran the real non-dry operator path in this worktree and truncated `config/hosts/intake/remembrance.json` and `remembrance.intake.json` to 0 bytes (breaking flake eval). They were restored with `git checkout --`; confirm at your tip that both files match HEAD and parse as JSON, and that no commit contains a truncated version.
- Todo 9's acceptance references the wave-3 eval wall (todo 11), not landed yet: verify the equivalent unit-field assertions directly (see cross_wave in the output schema).
- Sibling-lane discipline: each commit must contain only its own todo's files. Note: T12 in wave 1 landed as two commits; that is out of scope here.

## Required output (write to file AND include in your final message)
Write `/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/wave2-verification.json`:
```json
{"verified_tip": "<full sha>", "verified_at": "<iso8601>",
  "todos": {"6": {"verdict": "...", "evidence": [], "repro": "...", "confidence": 0.0}, "7": {...}, "8": {...}, "9": {...}, "15": {...}},
  "adversarial": {"stale_state": "...", "dirty_worktree": "...", "misleading_success_output": "...", "malformed_input": "..."},
  "cross_wave": "t9 acceptance vs t11 wall — what was verified directly",
  "drift": "...", "cleanup": ["..."]}
```

## Rules
- Read-only on the worktree; no edits, no commits, no pushes. Scratch only under /tmp,
  cleaned up with a receipt. Be adversarial: try to falsify each claim; an unreproducible
  claim is `needs-fix`/`needs-human-review`, never a shrug.
