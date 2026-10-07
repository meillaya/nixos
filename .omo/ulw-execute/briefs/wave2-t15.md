# Wave 2 lane brief — plan `thinkpad-zero-touch-install`

You are ONE LANE of a parallel wave executing the work plan `/home/mei/nixos/.omo/plans/thinkpad-zero-touch-install.md`.
Read the whole plan first, then your todo section below (verbatim from the plan).

## Your worktree — ALL edits, commands and tests happen here
- Worktree root: `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave2` (branched from `main` AFTER the previous wave landed).
- `cd /home/mei/nixos-wt/thinkpad-zero-touch-install-wave2` for every command; use `git -C /home/mei/nixos-wt/thinkpad-zero-touch-install-wave2 ...` for git.
- The plan and research notes live in the main checkout; read them at `/home/mei/nixos/...`.
  Where the plan's acceptance commands use `/home/mei/nixos`, substitute the worktree
  root `/home/mei/nixos-wt/thinkpad-zero-touch-install-wave2` — a flake evaluation of the MAIN checkout would not contain your work.
- Sibling lanes edit OTHER files concurrently in this same worktree. Never edit files
  outside your scope. If a repo-wide `nix` evaluation fails inside another lane's file,
  retry once, then report; do not fix it.
- Flake evaluation only sees the git tree: `git add` a NEW file before any `nix` flake
  command that must see it.
## Inter-wave context
- Wave 1 is merged into main and your worktree is off that main: `bin/_install-staging.sh`
  (staging_init/staging_password/staging_artifacts/staging_identity/staging_plan),
  `bin/host-install.sh` `--extra-files`/`--chown`/attempt-marker transport, `pkgs.mkpasswd`
  in apps.nix installDeps, ISO btrfs support, and tests/bootstrap-password-mutations.sh all exist.
  Read the actual files; do not assume signatures from memory.

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
- [ ] 15. Operator path: mint and stage the password
  What to do / Must NOT do: in `bin/host-install.sh`, when it is the entry point (i.e. NOT `--install-only`), source `bin/_install-staging.sh`, create a stage under `$tmpdir`, mint the password hash (`staging_init` + `staging_password`), print it once, and hand `--extra-files "$stage"` (with the same `--chown` pair the helper reports) to its own nixos-anywhere call at `:201`; skip the whole step under `--install-only` (the app supplies its own stage through the same flags). Add an explicit, off-by-default `--stage-identity SRC` that copies SRC in as the user-owned key; MUST NOT stage the operator machine's own identity by default. Do NOT duplicate the staging logic (source the helper); do NOT write the password to disk outside the tmpfs stage.
  Closes: GAP-1 (operator path)
  Parallelization: Wave 2 | Blocked by: 3,4 | Blocks: 13
  References: `bin/host-install.sh:88-89` (`tmpdir`), `:193-206` (`stage_install`), the recovered historical script (`.omo/ulw-research/20261006-100350/wave-1-lane2.md`); `docs/service-notes/nixos-anywhere-iso-install.md:10` (the operator entry point).
  Acceptance criteria (agent-executable): `bash bin/host-install.sh --dry-run --target-host 1.2.3.4` prints the password-staging step and no secret; a run under `--install-only` prints no staging step; the code sources `bin/_install-staging.sh`.
  QA scenarios (name the exact tool + invocation): happy - the two dry-run invocations above; failure - run the full-path dry-run with a stubbed failing `mkpasswd` and assert the script dies before invoking nixos-anywhere. Evidence `<attemptDir>/task-15-thinkpad-zero-touch-install.log`
  Recommended task executor category: deep-low
  Commit: Y | `feat(install): mint and stage the password on the operator path`


## Lane-specific adversarial probes
- malformed_input: stubbed failing `mkpasswd` => the script dies before invoking nixos-anywhere; `--stage-identity` with a missing SRC must die.
- misleading_success_output: full-path `--dry-run --target-host 1.2.3.4` prints the staging step and NO secret; `--install-only` prints NO staging step; the marker/transport from wave 1 stay intact.
- stale_state: the stage under `$tmpdir` is recreated per run (fresh password each run); identity is staged only with the explicit `--stage-identity` flag — never the operator's own key by default.
- dirty_worktree: `git show --stat HEAD` lists only `bin/host-install.sh` (+ test files it must touch, if any).
- hung_or_long_commands: dry-runs only; wrap in timeouts.
