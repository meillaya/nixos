# Wave-3 independent adversarial verifier — plan `thinkpad-zero-touch-install`

You are the INDEPENDENT VERIFIER for wave 3 (todos 10, 11, 13, 14). You did not implement
any of this work. A worker's DoneClaim is NEVER taken at face value; `confirmed` is the
only pass verdict.

## Sources of truth
- Plan: `/home/mei/nixos/.omo/plans/thinkpad-zero-touch-install.md` (read it fully).
- Worktree under verification: `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave3` (branch `thinkpad-zero-touch-install/wave3`).
- Record the tip (`git rev-parse HEAD`) at start; if it moves, note it and verify at the
  CURRENT tip reporting which commits you verified. Never fix anything — report only.
- Worker evidence: `/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/task-{10,11,13,14}-*`.

## Verified commits claimed (main..HEAD order)
```
5d4052f fix(iso): give the autoinstall unit a usable PATH
a1c86ad test(iso): prove the gate is inert on a plain boot
19e2e11 test(install): pin the staging and transport invariants
0cc6c55 docs(install): document staging, the opt-in gate, and the rescue route
9eb23e0 test(iso): pin the autostart unit and the inert-by-default assertion
```

## Method — per todo
For EACH of todos 10, 11, 13, 14:
1. Read the plan's section (verbatim acceptance criteria + QA scenarios).
2. Re-run the ACCEPTANCE commands yourself in the worktree (flake evals with the worktree
   root, `timeout 900/1500`, capture full output).
3. Re-run the QA failure variants in SCRATCH COPIES under /tmp (token removal for t10/t11,
   docs-flag absence for t13, condition flip for t14) — never mutate the worktree.
4. `git show --stat <hash>` per commit: exactly the todo's files; no secrets, no `.direnv`,
   no `.omo` product edits.
5. Adversarial probes (explicit results):
   - `flaky_tests`: t10/t11/t12 scripts run TWICE; the t14 VM test must be deterministic —
     re-run `nix build .#checks.x86_64-linux.iso-autostart-vm` (store-cached if built) and
     confirm the assertions are event/state-based, not timing-based.
   - `misleading_success_output`: each new check FAILS when its pinned token/condition is
     removed (scratch copies); the t14 twin-boot proves variant (a) inactive and variant
     (b) rescue-active with the app dying at host-match; no pass-by-construction.
   - `stale_state`: evals reflect the current files (run twice, identical).
   - `dirty_worktree`: tree clean at tip; commits contain only their files.
   - `hung_or_long_commands`: the VM build under a bound; report its real duration.
   - `malformed_input`, `prompt_injection`, `cancel_resume`: report `n/a — <reason>` where
     the trigger facts do not hold.
6. t11 note: the wall must include the NEGATIVE assertion (`nixos.autoinstall=1` NOT in
   `boot.kernelParams`) and must not weaken existing assertions.


## Wave-3 special notes
- The F-B fix (`5d4052f`) modified `modules/flake/iso-images.nix` (adds `path = [ pkgs.bash pkgs.coreutils pkgs.nix ]` to the nixos-autoinstall unit) and `tests/iso-autostart-vm.nix` (assertions tightened to fail-before/pass-after observables: wrapper banner `Running install for x86_64-linux` + `install: `). Re-confirm the t11 eval wall still passes and the unit fields still match the plan at this tip.
- The todo-14 VM test's gatedBoot asserts the shipped safe-failure chain; the app dies at its first `nix eval` inside the VM's offline sandbox (documented) — on real hardware the network is supplied by `after network-online.target`. Judge whether the landed assertions honestly pin the plan's intent; note the limitation.
- Known environmental facts: `nix build` of some checks is heavy; disk was tight (a gc freed 6.3G; check `df` before heavy builds; do not gc yourself). A separate diagnostic (F-A) may be running in /tmp — do not touch it.
- The wave-3 branch also contains the earlier rebase (docs commit 0cc6c55 after dropping a force-added bin/AGENTS.md; T10 replayed as 19e2e11) — treat as known and accepted; bin/AGENTS.md is intentionally untracked.

## Required output (write to file AND include in your final message)
Write `/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/wave3-verification.json`:
```json
{"verified_tip": "<full sha>", "verified_at": "<iso8601>",
  "todos": {"10": {"verdict": "...", "evidence": [], "repro": "...", "confidence": 0.0}, "11": {...}, "13": {...}, "14": {...}},
  "adversarial": {"flaky_tests": "...", "misleading_success_output": "...", "stale_state": "...", "dirty_worktree": "...", "vm_duration": "..."},
  "drift": "...", "cleanup": ["..."]}
```

## Rules
- Read-only on the worktree; no edits, no commits, no pushes. Scratch only under /tmp,
  cleaned up with a receipt. An unreproducible claim is `needs-fix`/`needs-human-review`.
