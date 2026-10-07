# Wave 1 lane brief — plan `thinkpad-zero-touch-install`

You are ONE LANE of a 5-lane parallel wave. Read the whole plan first: `/home/mei/nixos/.omo/plans/thinkpad-zero-touch-install.md`.
Further context is in `/home/mei/nixos/.omo/ulw-research/20261006-100350/` when the plan cites it.

## Your worktree — ALL edits, commands and tests happen here
- Worktree root: `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave1` (branch `thinkpad-zero-touch-install/wave1`, based on main 5a33373).
- `cd /home/mei/nixos-wt/thinkpad-zero-touch-install-wave1` for every command. Use `git -C /home/mei/nixos-wt/thinkpad-zero-touch-install-wave1 ...` for git.
- The plan and the research notes live in the main checkout; read them at `/home/mei/nixos/...`.
  When the plan's acceptance commands use the absolute path `/home/mei/nixos`, substitute
  your worktree root `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave1` — a `nix` flake evaluation of the MAIN checkout would NOT
  contain your uncommitted work.
- Other lanes edit OTHER files in this same worktree concurrently. Never edit files
  outside your scope. If a repo-wide `nix` evaluation fails inside a file outside your
  scope, wait/retry once (`nix` re-reads the tree), then report it; do not "fix" it.
- Because flake evaluation only sees the git tree, `git add` a NEW file before any
  `nix` flake command that must see it.

## Commit policy (plan `## Commit strategy`)
- One atomic commit per todo, message EXACTLY as the plan's `Commit:` line says.
- `git add` only your own explicit paths (never `git add -A`/`-u`); commit with
  `git commit -m '<message>' -- <paths>` style discipline.
- If `index.lock` contention happens (parallel lanes), wait a second and retry.
- Never commit a plaintext password, a staging tmpdir, or any `.direnv` path.
- Do not push, do not merge, do not rebase, do not touch other branches or the plan file.
- Do not edit anything under `/home/mei/nixos/.omo/` except your own evidence file.

## Evidence
Capture REAL command output (use `2>&1 | tee -a <evidence>`), then write your evidence
artifact(s) to `/home/mei/nixos/.omo/evidence/thinkpad-zero-touch-install/task-<N>-thinkpad-zero-touch-install.<ext>` for each todo N you own
(exact file names are in each todo's "Evidence" line). The evidence dir may not exist in
your worktree — write to that absolute main-checkout path.

## Completion protocol (mandatory, exact)
End your final message with one filled JSON object per todo you completed:
`DoneClaim: {"task": "<N: title>", "changed_files": [...], "tests": ["<exact command> => <result>"], "manual_qa": ["<artifact path>"], "cleanup": ["<receipt or none>"], "risks": [...]}`
Never claim a pass you did not observe. If something could not be executed, say exactly
why in `risks` instead of inventing a result.

## Adversarial probes (run each; record observable result, or `n/a — reason`)
## Your todo
- [ ] 12. Tests: restore the password mutation test
  What to do / Must NOT do: re-create `tests/bootstrap-password-mutations.sh` from the recovered original (`.omo/ulw-research/20261006-100350/wave-1-lane2.md` holds the importer shape: `nix eval --json --impure --expr "import $root/tests/bootstrap-password-config-eval.nix { config = ... }" | jq -e <filter>`), aimed at `nixosConfigurations.remembrance.config` (the config-eval file's own convention), and wire it into `modules/flake/checks.nix` (nix-eval based, sandbox-safe). Do NOT alter `tests/bootstrap-password-config-eval.nix`; do NOT wire the lifecycle suite.
  Closes: GAP-7 (un-orphans the config-eval)
  Parallelization: Wave 1 | Blocked by: - | Blocks: -
  References: recovered `tests/bootstrap-password-mutations.sh` (f7015a56) and the orphan `tests/bootstrap-password-config-eval.nix:3-23`; `modules/flake/checks.nix:38-51` (the eval check shape).
  Acceptance criteria (agent-executable): `bash tests/bootstrap-password-mutations.sh` exits 0; the check appears in `nix flake check --all-systems --no-build` output evaluation.
  QA scenarios: happy - run the script; failure - temporarily set `users.mutableUsers = false` in a scratch copy and confirm the mutation assertions fail. Evidence `<attemptDir>/task-12-thinkpad-zero-touch-install.log`
  Recommended task executor category: unspecified-low
  Commit: Y | `test(install): restore the bootstrap-password mutation coverage`


## Lane-specific adversarial probes
- flaky_tests: run `bash tests/bootstrap-password-mutations.sh` TWICE in a row; both runs must pass
  deterministically (no timing dependence, no store-cache dependence).
- misleading_success_output: the mutation script must actually be able to FAIL — in a scratch COPY
  (e.g. `cp tests/bootstrap-password-config-eval.nix /tmp/...`), flip `users.mutableUsers` (or the
  equivalent pinned token the script reads) and show the copied script fails. Never mutate the real
  file. Paste the failing output.
- stale_state: the script's evals must be fresh (`--json --impure`, no reuse of an old result file);
  show the exact `nix eval` command it runs and re-run one by hand.
- dirty_worktree: `git show --stat HEAD` lists only `tests/bootstrap-password-mutations.sh` and
  `modules/flake/checks.nix` (plus nothing else).
- long_external_commands: `nix flake check --all-systems --no-build` is required by the acceptance;
  wrap it in `timeout 1500`, and if it fails ONLY inside a file owned by another lane, retry once
  and record both outputs.
