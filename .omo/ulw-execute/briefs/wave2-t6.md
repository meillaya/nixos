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
- [ ] 6. App: stage the password and forward the transport
  What to do / Must NOT do: in `apps/x86_64-linux/install`, source `bin/_install-staging.sh`; add a staging step between `fold_host_key`/`save_artifacts` and `setup_self_ssh` (after `:358`) that calls `staging_init` + `staging_password` and passes `--extra-files "$stage"` plus the helper-reported ownership pair (`--chown home/<user>/.config <uid>:<gid>`) through `install_phase` (`:328-332`); show the staging step in the `--dry-run` plan (`:158-165`). Keep the existing `--install-only`/`auto_enroll` strings in the plan text (`tests/dendritic-apps.sh:27-29`). Do NOT print the password when `--dry-run`; do NOT write it to disk; do NOT pass any `--chown` path other than the reported `.config` subtree.
  Closes: GAP-1
  Parallelization: Wave 2 | Blocked by: 3,4,5 | Blocks: 7,8,9
  References: `apps/x86_64-linux/install:80-132` (parser), `:229-286` (`enroll`), `:313-324` (`save_artifacts`), `:325-333` (`install_phase`), `:354-371` (final flow); validator contract `modules/nixos/bootstrap-password.nix:44-84`.
  Acceptance criteria (agent-executable): `./apps/x86_64-linux/install --dry-run` prints the staging step, the `--extra-files` transport, and the exact `--chown home/<user>/.config <uid>:<gid>` pair, and no `password for` line; the code contains exactly one `password for` print; `bash tests/dendritic-apps.sh` passes.
  QA scenarios: happy - the dry-run above; failure - run with a stubbed failing `mkpasswd` and assert the app exits non-zero before invoking host-install.sh. Evidence `<attemptDir>/task-6-thinkpad-zero-touch-install.log`
  Recommended task executor category: deep-low
  Commit: Y | `feat(install): generate and stage the per-install password`


## Lane-specific adversarial probes
- malformed_input: run with a stubbed failing `mkpasswd` and prove the app exits non-zero BEFORE invoking host-install.sh (no partial install).
- misleading_success_output: `--dry-run` must print the staging step, the `--extra-files` transport and the exact `--chown home/<user>/.config <uid>:<gid>` pair, and must print NO `password for` line; the code contains exactly one `password for` print (grep count).
- stale_state: prove the stage is a fresh tmpfs dir per run and the password hash is regenerated (two dry-run/staging runs differ).
- dirty_worktree: `git show --stat HEAD` lists only `apps/x86_64-linux/install`.
- hung_or_long_commands: any nix command wrapped in `timeout 900`.
