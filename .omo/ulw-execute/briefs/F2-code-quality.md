# F2 — Code quality review (final verification wave)

You review the quality of the delivered work on plan `/home/mei/nixos/.omo/plans/thinkpad-zero-touch-install.md`.
Read the plan fully. You do not fix anything; you report.

## Scope (the plan's own F2 row)
"the new shell passes `bash -n`; no dead code; the helper is sourced by exactly the intended
caller; commits are atomic and match the strategy."

## Method
- Read-only in the worktree copy `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave3` (identical tree to landed main; also inspect
  git history there: `git log --oneline --stat <wave commits>`).
- `bash -n` every changed/new shell file: `bin/_install-staging.sh`, `bin/host-install.sh`,
  `apps/x86_64-linux/install`, `tests/install-staging.sh`, `tests/bootstrap-password-mutations.sh`.
- Dead code: check the new functions in `bin/_install-staging.sh` are all used
  (`staging_init`, `staging_password`, `staging_artifacts`, `staging_identity`, `staging_plan`)
  and that no unused leftovers exist in the app/host-install diffs.
- Caller discipline: `grep -rn '_install-staging.sh' bin/ apps/ tests/` — the intended callers
  are the app (`apps/x86_64-linux/install`) and the operator entry point (`bin/host-install.sh`
  when not `--install-only`). Flag any other source, any duplicated staging logic, or any
  copy-paste of the helper's internals.
- Commit strategy: one commit per todo, conventional messages, wave order; specifically assess
  the two known deviations and say if they are acceptable: (a) todo 12 landed as two commits
  (`bde4937` + `b210a75`, a sandbox-HOME fixup), (b) the wave-2 verify-fix commit `bf90e20` and
  the wave-3 rebase that dropped a force-added `bin/AGENTS.md` (docs commit `ae0a3ef` ->
  `0cc6c55`; T10 replayed `a25219f` -> `19e2e11`). Check no commit contains secrets,
  stage dirs, `.direnv` paths, or unrelated files.
- Nix quality: read the iso-images.nix unit definition and checks.nix additions for
  obvious smells (duplication, hardcoded store paths, `lib.mkForce` misuse).

## Output
Write `/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/F2-code-quality.md`: findings with
file:line, severity (blocker/major/minor/nit), and the command that shows it. End your message:
`F2Report: {"verdict": "APPROVE|REJECT", "blockers": [], "majors": [], "minors": ["..."], "commit_strategy": "<assessment incl. the two deviations>"}`
REJECT only for a blocker (broken code, failing `bash -n`, dead/duplicated logic that changes
behavior, a commit containing a secret or an unrelated file).
