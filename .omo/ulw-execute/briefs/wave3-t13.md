# Wave 3 lane brief — plan `thinkpad-zero-touch-install`

You are ONE LANE of a parallel wave executing the work plan `/home/mei/nixos/.omo/plans/thinkpad-zero-touch-install.md`.
Read the whole plan first, then your todo section below (verbatim from the plan).

## Your worktree — ALL edits, commands and tests happen here
- Worktree root: `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave3` (branched from `main` AFTER the previous wave landed).
- `cd /home/mei/nixos-wt/thinkpad-zero-touch-install-wave3` for every command; use `git -C /home/mei/nixos-wt/thinkpad-zero-touch-install-wave3 ...` for git.
- The plan and research notes live in the main checkout; read them at `/home/mei/nixos/...`.
  Where the plan's acceptance commands use `/home/mei/nixos`, substitute the worktree
  root `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave3` — a flake evaluation of the MAIN checkout would not contain your work.
- Sibling lanes edit OTHER files concurrently in this same worktree. Never edit files
  outside your scope. If a repo-wide `nix` evaluation fails inside another lane's file,
  retry once, then report; do not fix it.
- Flake evaluation only sees the git tree: `git add` a NEW file before any `nix` flake
  command that must see it.
## Inter-wave context
- Waves 1-2 are merged into main and your worktree is off that main: the staging helper,
  the app staging/identity/rescue/verify-host-match flow, the ISO gated unit + `flake.isoConfig`,
  and the operator-path staging all exist. Read the actual files; do not assume from memory.

## Commit policy
- One atomic commit per todo, message EXACTLY as the plan's `Commit:` line says.
- `git add` only your own explicit paths (never `git add -A`/`-u`). On `index.lock`
  contention, wait a second and retry. Never commit a plaintext password, a staging
  tmpdir, or any `.direnv` path. Do not push/merge/rebase/touch other branches or the plan.
- Do not edit anything under `/home/mei/nixos/.omo/` except your own evidence file.

## Evidence
Capture REAL command output (`2>&1 | tee -a <evidence>`), then write your evidence
artifact(s) to `/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/task-<N>-thinkpad-zero-touch-install.<ext>` for each todo N you own
(exact names in the todo's "Evidence" line).

## Completion protocol (mandatory, exact)
End your final message with one filled JSON object per todo you completed:
`DoneClaim: {"task": "<N: title>", "changed_files": [...], "tests": ["<exact command> => <result>"], "manual_qa": ["<artifact path>"], "cleanup": ["<receipt or none>"], "risks": [...]}`
Never claim a pass you did not observe; record unexecutable steps in `risks` with the reason.

## Adversarial probes (run each; record observable result, or `n/a — reason`)
## Your todo
- [ ] 13. Docs
  What to do / Must NOT do: update `README.md` (the install section: the new staging, the optional autostart gate and how to switch it on at the boot menu, the rescue route, what the official ISO cannot do), `docs/service-notes/new-machine-ssh-install.md` and `docs/service-notes/nixos-anywhere-iso-install.md` (same), and `bin/AGENTS.md` (the new flags). Do NOT document anything the tests do not assert; do NOT claim the ISO boots are exercised beyond the VM gate test.
  Closes: IS-6
  Parallelization: Wave 3 | Blocked by: 6,7,8,9 | Blocks: -
  References: `README.md` install section; the two service notes; `bin/AGENTS.md`; the shipped flag names.
  Acceptance criteria (agent-executable): `grep -Fq -- '--extra-files' README.md docs/service-notes/*.md`; `grep -Fq 'nixos.autoinstall=1' docs/service-notes/nixos-anywhere-iso-install.md`; the prose matches the actual flags (spot-check by reading).
  QA scenarios: happy - the greps above; failure - grep for a removed flag and confirm absence. Evidence `<attemptDir>/task-13-thinkpad-zero-touch-install.md`
  Recommended task executor category: writing
  Commit: Y | `docs(install): document staging, the opt-in gate, and the rescue route`

## Final verification wave
> Runs in parallel after ALL todos. ALL must APPROVE. Surface results and wait for the user's explicit okay before declaring complete.
- [ ] F1. Plan compliance audit - every todo's acceptance was run; every Must-NOT holds (grep for `nixos.autoinstall=1` outside docs/tests; no plaintext password; no `|| true` in the unit).
- [ ] F2. Code quality review - the new shell passes `bash -n`; no dead code; the helper is sourced by exactly the intended caller; commits are atomic and match the strategy.
- [ ] F3. Real manual QA - run `nix flake check --all-systems --no-build`, the full script suite, and the deliberate validator proof (`unshare -Ur -m` against the produced hash); record transcripts.
- [ ] F4. Ideal-state fidelity - check IS-1..IS-7 row by row against the shipped behavior and the QA evidence; a shortfall becomes new `- [ ] N.` todos, never a note.

## Commit strategy

One commit per todo, conventional types as listed, in wave order. Commit 3 (the helper) intentionally has no callers; it is wired in todo 6. Commits 1 and 2 are independent leaves. No commit may contain a staged secret, a generated stage dir, or an updated `.direnv` path. The plan's Must-NOT rows are checked in F1 before any commit is considered final; the docs commit comes last.

## Success criteria
> One row per IS row. The plan is complete only when every IS row has a delivering todo and a proving QA scenario; F4 checks the delivered behavior against these rows 1:1, and a shortfall becomes new `- [ ] N.` rows, never a note.

| IS | Delivering todo(s) | Proving QA scenario | Evidence |
| --- | --- | --- | --- |
| IS-1 | 3,4,5,6,15 | todo 3's modes/regex run + todo 6's dry-run and stub-failure scenarios + todo 15's operator-path dry-run and staging run; the deliberate validator proof | `<attemptDir>/task-3-*.log`, `<attemptDir>/task-6-*.log`, `<attemptDir>/task-15-*.log` |
| IS-2 | 7,9 | todo 7's staging-tree scenario | `<attemptDir>/task-7-*.log` |
| IS-3 | 8,9 | todo 8's rescue dry-run + scratch equality test | `<attemptDir>/task-8-*.log` |
| IS-4 | 9,11,14 | todo 11's negative kernelParams assertion + todo 14's twin-boot VM (inactive by default; rescue after the gated attempt) | `<attemptDir>/task-11-*.log`, `<attemptDir>/task-14-*.log` |
| IS-5 | 4,8,9,15 | todo 4's marker-order grep + todo 8's mismatch-dies scenario + todo 15's skip-under-`--install-only` assertion + F1 | `<attemptDir>/task-4-*.log`, `<attemptDir>/task-8-*.log`, `<attemptDir>/task-15-*.log` |
| IS-6 | 10,11,12,13 | the three check scripts + the doc greps | `<attemptDir>/task-10-*.log`, `<attemptDir>/task-11-*.log`, `<attemptDir>/task-12-*.log`, `<attemptDir>/task-13-*.md` |
| IS-7 | (constraint; enforced by Must-NOT + F1) | F1's audit finds no second install path | F1 transcript |


## Lane-specific adversarial probes
- misleading_success_output: docs must match shipped flags — every documented flag must exist in the code (grep each); the failure scenario greps for a removed flag and asserts absence.
- stale_state / flaky_tests / malformed_input: n/a — prose; the greps in the acceptance are the proof.
- dirty_worktree: `git show --stat HEAD` lists only README.md + the two service notes + bin/AGENTS.md.
