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
- [ ] 7. App: stage the artifacts and the identity; retire the `--save` requirement
  What to do / Must NOT do: extend the staging step to include `staging_artifacts` (the candidate, intake document, host key from the enrollment staging dir) and `staging_identity` (source `$SOPS_AGE_KEY_FILE` else `~/.config/sops/age/keys.txt`, warn-and-continue if absent); replace the `want_save && -z "$save_dir"` hard die (`:360-364`) with a warning that the artifacts now persist in the installed system; keep `--save` as an optional escape hatch. Do NOT feed the rescued identity into the fold (`bin/_host_key_enroll.py` requires a store it cannot decrypt); do NOT chown anywhere except the reported `home/<user>/.config` argument.
  Closes: GAP-2, GAP-3 (partial)
  Parallelization: Wave 2 | Blocked by: 6 | Blocks: 10
  References: `apps/x86_64-linux/install:288-311` (`fold_host_key`), `:313-324` (`save_artifacts`), `:360-364` (the die); `scripts/hardware/auto_enroll_core.py` (artifact paths); research §2 (identity is the irreversible item).
  Acceptance criteria (agent-executable): `--dry-run` lists the enrollment-artifact and identity staging; the app no longer exits when `--save` is omitted and no store exists (assert with a fake staging run); grep shows the identity source fallback order.
  QA scenarios: happy - dry-run + a staging-only run in a scratch workdir with a fake key file (assert the tree layout and modes); failure - no key file anywhere => warn but continue (no die). Evidence `<attemptDir>/task-7-thinkpad-zero-touch-install.log`
  Recommended task executor category: deep-low
  Commit: Y | `feat(install): persist artifacts and the age identity into the target`


## Lane-specific adversarial probes
- malformed_input / long flows: no key file anywhere => warn-and-continue (no die); a malformed/unreadable key file must warn, not crash the run.
- misleading_success_output: the `--save` downgrade must still store artifacts when the operator explicitly passes `--save DIR` (escape hatch works); assert both paths.
- stale_state: a staging-only run with a fake key file must produce the tree layout with correct modes each run (assert 0700/0600 and the `home/<user>/.config/sops/age/keys.txt` path).
- dirty_worktree: `git show --stat HEAD` lists only `apps/x86_64-linux/install`.
- hung_or_long_commands: n/a (shell only, staged scratch runs); wrap nix in `timeout 900` if used.
